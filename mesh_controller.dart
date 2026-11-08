import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_mesh_flutter/core/crypto/identity.dart';
import 'package:offline_mesh_flutter/core/db/database_helper.dart';
import 'package:offline_mesh_flutter/core/mesh/mesh_packet.dart';
import 'package:offline_mesh_flutter/core/mesh/mesh_router_engine.dart';
import 'package:offline_mesh_flutter/core/mesh/nearby_hybrid_service.dart';
import 'package:offline_mesh_flutter/core/webrtc/serverless_webrtc_manager.dart';

final meshControllerProvider =
    StateNotifierProvider<MeshController, MeshState>((ref) {
  return MeshController();
});

class MeshState {
  const MeshState({
    this.ready = false,
    this.towerOn = true,
    this.profile,
    this.friends = const [],
    this.pending = const [],
    this.discovered = const [],
  });

  final bool ready;
  final bool towerOn;
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> friends;
  final List<Map<String, dynamic>> pending;
  final List<Map<String, dynamic>> discovered;

  MeshState copyWith({
    bool? ready,
    bool? towerOn,
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>>? friends,
    List<Map<String, dynamic>>? pending,
    List<Map<String, dynamic>>? discovered,
  }) {
    return MeshState(
      ready: ready ?? this.ready,
      towerOn: towerOn ?? this.towerOn,
      profile: profile ?? this.profile,
      friends: friends ?? this.friends,
      pending: pending ?? this.pending,
      discovered: discovered ?? this.discovered,
    );
  }
}

class MeshController extends StateNotifier<MeshState> {
  MeshController() : super(const MeshState());

  final db = DatabaseHelper.instance;
  final identityService = IdentityService();
  NearbyHybridService? nearby;
  MeshRouterEngine? router;
  ServerlessWebRTCManager? webrtc;
  StreamSubscription? _peerSub;
  StreamSubscription? _packetSub;

  Future<void> bootstrap() async {
    final profile = await db.getProfile();
    if (profile == null) {
      state = state.copyWith(ready: true);
      return;
    }
    await _startStack(
      userId: profile['user_id'] as String,
      username: profile['username'] as String,
    );
    await refreshLists();
    state = state.copyWith(ready: true, profile: profile);
  }

  Future<void> completeOnboarding({
    required String username,
    String? bio,
    String? avatarPath,
  }) async {
    final id = await identityService.createOrLoad(username: username);
    await db.upsertProfile(
      userId: id.userId,
      username: username,
      bio: bio,
      avatarPath: avatarPath,
    );
    await _startStack(userId: id.userId, username: username);
    await refreshLists();
    state = state.copyWith(
      ready: true,
      profile: await db.getProfile(),
    );
  }

  Future<void> _startStack({
    required String userId,
    required String username,
  }) async {
    nearby = NearbyHybridService(username: username, userId: userId);
    router = MeshRouterEngine(
      selfId: userId,
      db: db,
      forward: (packet, {exceptEndpointId}) async {
        if (!state.towerOn && packet.hopCount > 0) return;
        await nearby!.sendPacket(packet, exceptEndpointId: exceptEndpointId);
      },
    );
    router!.onDelivered = _onPacket;
    await nearby!.start(engine: router!);
    webrtc = ServerlessWebRTCManager(
      sendSignal: (signal) async {
        final to = signal['toUserId'] as String?;
        if (to == null) return;
        await nearby!.sendCallSignal(toUserId: to, signal: signal);
      },
    );
    await webrtc!.initRenderers();
    _peerSub?.cancel();
    _peerSub = nearby!.peerEvents.listen((e) async {
      if (e['phase'] == 'found') {
        await db.upsertFriend({
          'user_id': e['endpointId'],
          'username': e['name'] ?? 'Nearby',
          'bio': '',
          'avatar_path': null,
          'status': 'discovered',
          'hops': 0,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'public_key': null,
        });
        await refreshLists();
      }
    });
  }

  Future<void> _onPacket(MeshPacket packet, String from) async {
    switch (packet.type) {
      case PacketType.friendReq:
        await db.upsertFriend({
          'user_id': packet.senderId,
          'username': packet.payload['username'] ?? 'User',
          'bio': packet.payload['bio'] ?? '',
          'avatar_path': null,
          'status': 'pending_in',
          'hops': packet.hopCount,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'public_key': null,
        });
        break;
      case PacketType.friendAccept:
        await db.upsertFriend({
          'user_id': packet.senderId,
          'username': packet.payload['username'] ?? 'User',
          'bio': packet.payload['bio'] ?? '',
          'avatar_path': null,
          'status': 'accepted',
          'hops': packet.hopCount,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'public_key': null,
        });
        break;
      case PacketType.chat:
        await db.insertMessage({
          'id': packet.msgId,
          'thread_id': packet.senderId,
          'sender_id': packet.senderId,
          'body': packet.payload['text'] ?? '',
          'kind': 'text',
          'created_at': packet.createdAt,
          'status': 'delivered',
          'file_path': null,
          'is_me': 0,
        });
        break;
      case PacketType.callSignal:
        await webrtc?.handleSignal(packet.payload);
        break;
      default:
        break;
    }
    await refreshLists();
  }

  Future<void> refreshLists() async {
    state = state.copyWith(
      friends: await db.acceptedFriends(),
      pending: await db.pendingIn(),
      discovered: await db.discovered(),
    );
  }

  Future<void> sendRequest(String userId) async {
    final p = state.profile;
    if (p == null || nearby == null) return;
    await nearby!.sendFriendRequest(
      toUserId: userId,
      myUsername: p['username'] as String,
      bio: p['bio'] as String?,
    );
    await db.upsertFriend({
      'user_id': userId,
      'username': 'Pending',
      'bio': '',
      'avatar_path': null,
      'status': 'pending_out',
      'hops': 0,
      'last_seen': DateTime.now().millisecondsSinceEpoch,
      'public_key': null,
    });
    await refreshLists();
  }

  Future<void> acceptRequest(String userId) async {
    final p = state.profile;
    if (p == null || router == null) return;
    final packet = MeshPacket(
      msgId: DateTime.now().millisecondsSinceEpoch.toString(),
      type: PacketType.friendAccept,
      senderId: p['user_id'] as String,
      recipientId: userId,
      ttl: MeshPacket.maxTtl,
      hopCount: 0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      payload: {
        'username': p['username'],
        'bio': p['bio'] ?? '',
      },
      route: [p['user_id'] as String],
    );
    await router!.originate(packet);
    await db.upsertFriend({
      'user_id': userId,
      'username': state.pending
              .firstWhere((e) => e['user_id'] == userId, orElse: () => {'username': 'Friend'})['username'] ??
          'Friend',
      'bio': '',
      'avatar_path': null,
      'status': 'accepted',
      'hops': 0,
      'last_seen': DateTime.now().millisecondsSinceEpoch,
      'public_key': null,
    });
    await refreshLists();
  }

  Future<void> sendMessage(String toUserId, String text) async {
    final p = state.profile;
    if (p == null || nearby == null) return;
    await nearby!.sendChat(toUserId: toUserId, text: text);
    await db.insertMessage({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'thread_id': toUserId,
      'sender_id': p['user_id'],
      'body': text,
      'kind': 'text',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'status': 'sent',
      'file_path': null,
      'is_me': 1,
    });
  }

  Future<void> setTower(bool on) async {
    state = state.copyWith(towerOn: on);
  }

  @override
  void dispose() {
    _peerSub?.cancel();
    _packetSub?.cancel();
    nearby?.stop();
    router?.dispose();
    webrtc?.dispose();
    super.dispose();
  }
}
