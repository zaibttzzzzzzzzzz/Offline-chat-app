import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:offline_mesh_flutter/core/mesh/mesh_packet.dart';
import 'package:offline_mesh_flutter/core/mesh/mesh_router_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

/// Google Nearby Connections hybrid: BLE discovery + Wi-Fi bandwidth when available.
/// Strategy: P2P_CLUSTER (many-to-many mesh-friendly).
class NearbyHybridService {
  NearbyHybridService({required this.username, required this.userId});

  final String username;
  final String userId;

  final _nearby = Nearby();
  final _uuid = const Uuid();
  MeshRouterEngine? router;

  final Map<String, String> endpointToUserId = {};
  final Map<String, String> userIdToEndpoint = {};
  final _peers = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get peerEvents => _peers.stream;

  bool _running = false;
  bool get isRunning => _running;

  Future<bool> ensurePermissions() async {
    final req = <Permission>[
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
      Permission.microphone,
      Permission.camera,
      Permission.notification,
    ];
    final statuses = await req.request();
    return statuses.values.every((s) => s.isGranted || s.isLimited || s.isRestricted);
  }

  Future<void> start({required MeshRouterEngine engine}) async {
    router = engine;
    await ensurePermissions();
    final serviceId = 'com.offlinemesh.flutter.mesh';
    final strategy = Strategy.P2P_CLUSTER;

    await _nearby.startAdvertising(
      username,
      strategy,
      onConnectionInitiated: _onInitiated,
      onConnectionResult: _onResult,
      onDisconnected: _onDisconnected,
      serviceId: serviceId,
    );

    await _nearby.startDiscovery(
      username,
      strategy,
      onEndpointFound: (id, name, serviceId) {
        _peers.add({
          'phase': 'found',
          'endpointId': id,
          'name': name,
        });
      },
      onEndpointLost: (id) {
        _peers.add({'phase': 'lost', 'endpointId': id});
      },
      serviceId: serviceId,
    );

    _running = true;
  }

  Future<void> stop() async {
    try {
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
      await _nearby.stopAllEndpoints();
    } catch (_) {}
    _running = false;
  }

  void _onInitiated(String endpointId, ConnectionInfo info) {
    _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: (endid, payload) async {
        if (payload.type != PayloadType.BYTES || payload.bytes == null) return;
        try {
          final packet = MeshPacket.decode(payload.bytes!);
          endpointToUserId[endid] = packet.senderId;
          userIdToEndpoint[packet.senderId] = endid;
          await router?.ingest(packet, endid);
        } catch (e) {
          debugPrint('payload decode error: $e');
        }
      },
      onPayloadTransferUpdate: (endid, update) {},
    );
    _peers.add({
      'phase': 'initiated',
      'endpointId': endpointId,
      'name': info.endpointName,
    });
  }

  void _onResult(String endpointId, Status status) {
    _peers.add({
      'phase': status == Status.CONNECTED ? 'connected' : 'rejected',
      'endpointId': endpointId,
    });
  }

  void _onDisconnected(String endpointId) {
    final uid = endpointToUserId.remove(endpointId);
    if (uid != null) userIdToEndpoint.remove(uid);
    _peers.add({'phase': 'disconnected', 'endpointId': endpointId});
  }

  Future<void> requestConnection(String endpointId) async {
    await _nearby.requestConnection(
      username,
      endpointId,
      onConnectionInitiated: _onInitiated,
      onConnectionResult: _onResult,
      onDisconnected: _onDisconnected,
    );
  }

  Future<void> sendPacket(MeshPacket packet, {String? exceptEndpointId}) async {
    final bytes = packet.encode();
    final payload = Payload.fromBytes(bytes);

    if (packet.recipientId.isNotEmpty) {
      final ep = userIdToEndpoint[packet.recipientId];
      if (ep != null && ep != exceptEndpointId) {
        await _nearby.sendBytesPayload(ep, bytes);
        return;
      }
    }

    // Fan-out to all connected endpoints except ingress (relay).
    final endpoints = userIdToEndpoint.values.toSet();
    for (final ep in endpoints) {
      if (ep == exceptEndpointId) continue;
      try {
        await _nearby.sendBytesPayload(ep, bytes);
      } catch (e) {
        debugPrint('send fail $ep: $e');
      }
    }
  }

  Future<void> sendFriendRequest({
    required String toUserId,
    required String myUsername,
    String? bio,
  }) async {
    final packet = MeshPacket(
      msgId: _uuid.v4(),
      type: PacketType.friendReq,
      senderId: userId,
      recipientId: toUserId,
      ttl: MeshPacket.maxTtl,
      hopCount: 0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      payload: {
        'username': myUsername,
        'bio': bio ?? '',
      },
      route: [userId],
    );
    await router?.originate(packet);
  }

  Future<void> sendChat({
    required String toUserId,
    required String text,
  }) async {
    final packet = MeshPacket(
      msgId: _uuid.v4(),
      type: PacketType.chat,
      senderId: userId,
      recipientId: toUserId,
      ttl: MeshPacket.maxTtl,
      hopCount: 0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      payload: {'text': text, 'kind': 'text'},
      route: [userId],
    );
    await router?.originate(packet);
  }

  Future<void> sendCallSignal({
    required String toUserId,
    required Map<String, dynamic> signal,
  }) async {
    final packet = MeshPacket(
      msgId: _uuid.v4(),
      type: PacketType.callSignal,
      senderId: userId,
      recipientId: toUserId,
      ttl: 4,
      hopCount: 0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      payload: signal,
      route: [userId],
    );
    await router?.originate(packet);
  }

  String presenceJson() => jsonEncode({'userId': userId, 'username': username});
}
