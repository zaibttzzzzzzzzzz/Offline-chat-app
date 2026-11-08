import 'dart:async';

import 'package:offline_mesh_flutter/core/db/database_helper.dart';
import 'package:offline_mesh_flutter/core/mesh/mesh_packet.dart';

typedef PacketHandler = Future<void> Function(MeshPacket packet, String fromEndpointId);
typedef ForwardFn = Future<void> Function(MeshPacket packet, {String? exceptEndpointId});

/// Store-and-forward multi-hop engine.
///
/// Physical range is still limited by radio + density of relay phones.
/// This does not create 500km links by itself.
class MeshRouterEngine {
  MeshRouterEngine({
    required this.selfId,
    required this.db,
    required this.forward,
  });

  final String selfId;
  final DatabaseHelper db;
  final ForwardFn forward;

  final _local = StreamController<MeshPacket>.broadcast();
  Stream<MeshPacket> get onLocalDelivery => _local.stream;

  PacketHandler? onDelivered;

  Future<void> ingest(MeshPacket packet, String fromEndpointId) async {
    if (packet.ttl <= 0) return;
    if (packet.route.contains(selfId)) return;
    if (await db.hasSeenPacket(packet.msgId)) return;
    await db.markSeenPacket(packet.msgId);

    final forMe = packet.recipientId.isEmpty || packet.recipientId == selfId;
    if (forMe) {
      _local.add(packet);
      await onDelivered?.call(packet, fromEndpointId);
    }

    final shouldRelay = packet.recipientId != selfId && packet.ttl > 1;
    if (shouldRelay) {
      final next = packet.forwardThrough(selfId);
      await forward(next, exceptEndpointId: fromEndpointId);
    }
  }

  Future<void> originate(MeshPacket packet) async {
    await db.markSeenPacket(packet.msgId);
    await forward(packet);
    if (packet.recipientId == selfId || packet.recipientId.isEmpty) {
      _local.add(packet);
    }
  }

  void dispose() {
    _local.close();
  }
}
