import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'offline_mesh.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE profile (
            user_id TEXT PRIMARY KEY,
            username TEXT NOT NULL,
            bio TEXT,
            avatar_path TEXT,
            created_at INTEGER NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE friends (
            user_id TEXT PRIMARY KEY,
            username TEXT NOT NULL,
            bio TEXT,
            avatar_path TEXT,
            status TEXT NOT NULL,
            hops INTEGER DEFAULT 0,
            last_seen INTEGER,
            public_key TEXT
          );
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            thread_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            body TEXT,
            kind TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            status TEXT NOT NULL,
            file_path TEXT,
            is_me INTEGER NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE groups (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            icon_path TEXT,
            admin_id TEXT NOT NULL,
            allow_add INTEGER NOT NULL,
            allow_send INTEGER NOT NULL,
            allow_call INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE group_members (
            group_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            PRIMARY KEY (group_id, user_id)
          );
        ''');
        await db.execute('''
          CREATE TABLE statuses_24h (
            id TEXT PRIMARY KEY,
            owner_id TEXT NOT NULL,
            body TEXT,
            media_path TEXT,
            scope TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            expires_at INTEGER NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE channels (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            owner_id TEXT NOT NULL,
            description TEXT,
            created_at INTEGER NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE channel_follows (
            channel_id TEXT PRIMARY KEY,
            followed_at INTEGER NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE seen_packets (
            msg_id TEXT PRIMARY KEY,
            seen_at INTEGER NOT NULL
          );
        ''');
      },
    );
  }

  Future<void> upsertProfile({
    required String userId,
    required String username,
    String? bio,
    String? avatarPath,
  }) async {
    final d = await db;
    await d.insert(
      'profile',
      {
        'user_id': userId,
        'username': username,
        'bio': bio ?? '',
        'avatar_path': avatarPath,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final d = await db;
    final rows = await d.query('profile', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertFriend(Map<String, dynamic> row) async {
    final d = await db;
    await d.insert('friends', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> acceptedFriends() async {
    final d = await db;
    return d.query('friends', where: "status = ?", whereArgs: ['accepted']);
  }

  Future<List<Map<String, dynamic>>> pendingIn() async {
    final d = await db;
    return d.query('friends', where: "status = ?", whereArgs: ['pending_in']);
  }

  Future<List<Map<String, dynamic>>> discovered() async {
    final d = await db;
    return d.query('friends', where: "status = ?", whereArgs: ['discovered']);
  }

  Future<void> insertMessage(Map<String, dynamic> row) async {
    final d = await db;
    await d.insert('messages', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> messagesForThread(String threadId) async {
    final d = await db;
    return d.query(
      'messages',
      where: 'thread_id = ?',
      whereArgs: [threadId],
      orderBy: 'created_at ASC',
    );
  }

  Future<bool> hasSeenPacket(String msgId) async {
    final d = await db;
    final rows = await d.query('seen_packets', where: 'msg_id = ?', whereArgs: [msgId]);
    return rows.isNotEmpty;
  }

  Future<void> markSeenPacket(String msgId) async {
    final d = await db;
    await d.insert(
      'seen_packets',
      {'msg_id': msgId, 'seen_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> purgeExpiredStatuses() async {
    final d = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await d.delete('statuses_24h', where: 'expires_at < ?', whereArgs: [now]);
  }
}
