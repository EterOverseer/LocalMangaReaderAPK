import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'manga_reader.db');
    return await openDatabase(
      dbPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE manga_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT NOT NULL UNIQUE,
        filename TEXT NOT NULL,
        title TEXT NOT NULL,
        chapter TEXT,
        ext TEXT NOT NULL,
        size INTEGER NOT NULL,
        modified_at INTEGER NOT NULL,
        indexed_at INTEGER NOT NULL,
        is_remote INTEGER NOT NULL DEFAULT 0,
        remote_source_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT NOT NULL DEFAULT '#808080',
        label TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE manga_tags (
        manga_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (manga_id, tag_id),
        FOREIGN KEY (manga_id) REFERENCES manga_files(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE reading_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        manga_id INTEGER NOT NULL UNIQUE,
        page INTEGER NOT NULL DEFAULT 0,
        total_pages INTEGER NOT NULL DEFAULT 0,
        last_read_at INTEGER NOT NULL,
        FOREIGN KEY (manga_id) REFERENCES manga_files(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE app_config (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE remote_sources (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        username TEXT,
        password TEXT,
        root_path TEXT NOT NULL DEFAULT '/'
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX idx_manga_title ON manga_files(title)');
    await db.execute('CREATE INDEX idx_manga_path ON manga_files(path)');
    await db.execute('CREATE INDEX idx_tags_name ON tags(name)');
    await db.execute('CREATE INDEX idx_reading_progress_manga ON reading_progress(manga_id)');
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await db.execute('''
        CREATE TABLE remote_sources (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          name TEXT NOT NULL,
          url TEXT NOT NULL,
          username TEXT,
          password TEXT,
          root_path TEXT NOT NULL DEFAULT '/'
        )
      ''');
      await db.execute('ALTER TABLE manga_files ADD COLUMN is_remote INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE manga_files ADD COLUMN remote_source_id INTEGER');
    }
  }

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }

  // --- Generic config helpers ---

  Future<void> setConfig(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_config',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getConfig(String key) async {
    final db = await database;
    final result = await db.query(
      'app_config',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  Future<Map<String, String>> getAllConfigs() async {
    final db = await database;
    final result = await db.query('app_config');
    return Map.fromEntries(
      result.map((r) => MapEntry(r['key'] as String, r['value'] as String)),
    );
  }
}
