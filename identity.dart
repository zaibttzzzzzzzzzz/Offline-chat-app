import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocalIdentity {
  LocalIdentity({
    required this.userId,
    required this.username,
    required this.publicKeyBase64,
    required this.privateKeyBase64,
  });

  final String userId;
  final String username;
  final String publicKeyBase64;
  final String privateKeyBase64;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'publicKeyBase64': publicKeyBase64,
        'privateKeyBase64': privateKeyBase64,
      };

  static LocalIdentity fromJson(Map<String, dynamic> j) => LocalIdentity(
        userId: j['userId'] as String,
        username: j['username'] as String,
        publicKeyBase64: j['publicKeyBase64'] as String,
        privateKeyBase64: j['privateKeyBase64'] as String,
      );
}

const _adjectives = [
  'Cyber',
  'Silent',
  'Swift',
  'Neon',
  'Iron',
  'Quantum',
  'Shadow',
  'Solar',
  'Mesh',
  'Nova',
];
const _nouns = [
  'Falcon',
  'Wolf',
  'Node',
  'Tower',
  'Relay',
  'Pixel',
  'Comet',
  'Raptor',
  'Forge',
  'Pulse',
];

String randomUsername() {
  final r = Random.secure();
  final a = _adjectives[r.nextInt(_adjectives.length)];
  final n = _nouns[r.nextInt(_nouns.length)];
  final num = 100 + r.nextInt(900);
  return '${a}${n}_$num';
}

class IdentityService {
  static const _key = 'local_identity_v1';

  Future<LocalIdentity?> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return null;
    return LocalIdentity.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<LocalIdentity> createOrLoad({String? username}) async {
    final existing = await load();
    if (existing != null && username == null) return existing;

    final algo = Ed25519();
    final keyPair = await algo.newKeyPair();
    final pub = await keyPair.extractPublicKey();
    final priv = await keyPair.extractPrivateKeyBytes();
    final id = LocalIdentity(
      userId: const Uuid().v4(),
      username: username ?? existing?.username ?? randomUsername(),
      publicKeyBase64: base64Encode(pub.bytes),
      privateKeyBase64: base64Encode(priv),
    );
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(id.toJson()));
    return id;
  }

  Future<LocalIdentity> updateUsername(String username) async {
    final cur = await load();
    if (cur == null) return createOrLoad(username: username);
    final next = LocalIdentity(
      userId: cur.userId,
      username: username.trim(),
      publicKeyBase64: cur.publicKeyBase64,
      privateKeyBase64: cur.privateKeyBase64,
    );
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(next.toJson()));
    return next;
  }
}
