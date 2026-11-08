import 'dart:convert';

enum PacketType {
  friendReq,
  friendAccept,
  friendReject,
  chat,
  fileMeta,
  fileChunk,
  groupInit,
  groupMsg,
  callSignal,
  status,
  channelPost,
  presence,
}

class MeshPacket {
  MeshPacket({
    required this.msgId,
    required this.type,
    required this.senderId,
    required this.recipientId,
    required this.ttl,
    required this.hopCount,
    required this.createdAt,
    required this.payload,
    this.route = const [],
  });

  final String msgId;
  final PacketType type;
  final String senderId;
  /// Empty string = broadcast / epidemic.
  final String recipientId;
  final int ttl;
  final int hopCount;
  final int createdAt;
  final Map<String, dynamic> payload;
  final List<String> route;

  static const maxTtl = 8;

  MeshPacket forwardThrough(String nodeId) {
    return MeshPacket(
      msgId: msgId,
      type: type,
      senderId: senderId,
      recipientId: recipientId,
      ttl: ttl - 1,
      hopCount: hopCount + 1,
      createdAt: createdAt,
      payload: Map<String, dynamic>.from(payload),
      route: [...route, nodeId],
    );
  }

  Map<String, dynamic> toJson() => {
        'msgId': msgId,
        'type': type.name,
        'senderId': senderId,
        'recipientId': recipientId,
        'ttl': ttl,
        'hopCount': hopCount,
        'createdAt': createdAt,
        'payload': payload,
        'route': route,
      };

  static MeshPacket fromJson(Map<String, dynamic> j) {
    return MeshPacket(
      msgId: j['msgId'] as String,
      type: PacketType.values.firstWhere(
        (e) => e.name == j['type'],
        orElse: () => PacketType.chat,
      ),
      senderId: j['senderId'] as String,
      recipientId: (j['recipientId'] as String?) ?? '',
      ttl: (j['ttl'] as num?)?.toInt() ?? 0,
      hopCount: (j['hopCount'] as num?)?.toInt() ?? 0,
      createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      payload: Map<String, dynamic>.from(j['payload'] as Map? ?? {}),
      route: (j['route'] as List?)?.map((e) => '$e').toList() ?? [],
    );
  }

  List<int> encode() => utf8.encode(jsonEncode(toJson()));

  static MeshPacket decode(List<int> bytes) {
    final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return MeshPacket.fromJson(map);
  }
}
