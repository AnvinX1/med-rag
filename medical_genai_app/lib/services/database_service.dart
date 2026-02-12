import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models.dart';
import 'dart:convert';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'medical_genai.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // precise migration or just drop/recreate for dev
          await db.execute('DROP TABLE IF EXISTS messages');
          await _createTables(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE sessions(
        id TEXT PRIMARY KEY,
        title TEXT,
        timestamp INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE messages(
        id TEXT PRIMARY KEY,
        sessionId TEXT,
        role TEXT,
        content TEXT,
        sources TEXT,
        processingTime REAL,
        timestamp INTEGER,
        FOREIGN KEY(sessionId) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');
  }

  // Session Methods
  Future<String> createSession({String? title}) async {
    final db = await database;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final session = ChatSession(
      id: id,
      title: title ?? 'New Chat',
      timestamp: DateTime.now(),
    );
    await db.insert('sessions', session.toMap());
    return id;
  }

  Future<List<ChatSession>> getSessions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => ChatSession.fromMap(maps[i]));
  }

  Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
    await db.delete('messages', where: 'sessionId = ?', whereArgs: [id]);
  }

  Future<void> updateSessionTitle(String id, String title) async {
    final db = await database;
    await db.update(
      'sessions',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Message Methods
  Future<void> insertMessage(ChatMessage message) async {
    final db = await database;
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Update session timestamp
    await db.update(
      'sessions',
      {'timestamp': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [message.sessionId],
    );
  }

  Future<List<ChatMessage>> getMessages(String sessionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) => ChatMessage.fromMap(maps[i]));
  }

  Future<void> clearMessages(String sessionId) async {
    final db = await database;
    await db.delete('messages', where: 'sessionId = ?', whereArgs: [sessionId]);
  }
}
