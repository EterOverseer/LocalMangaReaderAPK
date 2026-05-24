import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/reading_progress.dart';

class ProgressRepository {
  final DatabaseHelper _db;

  ProgressRepository(this._db);

  /// Get reading progress for a manga.
  Future<ReadingProgress?> getProgress(int mangaId) async {
    final db = await _db.database;
    final rows = await db.query(
      'reading_progress',
      where: 'manga_id = ?',
      whereArgs: [mangaId],
    );
    if (rows.isEmpty) return null;
    return ReadingProgress.fromMap(rows.first);
  }

  Future<List<Map<String, dynamic>>> getAllProgressRaw() async {
    final db = await _db.database;
    return await db.query('reading_progress');
  }

  Future<void> upsertProgressRaw(Map<String, dynamic> data) async {
    final db = await _db.database;
    await db.insert('reading_progress', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Save reading progress (upsert).
  Future<void> saveProgress(ReadingProgress progress) async {
    final db = await _db.database;
    final existing = await db.query(
      'reading_progress',
      where: 'manga_id = ?',
      whereArgs: [progress.mangaId],
    );

    final map = progress.toMap()..remove('id');

    if (existing.isNotEmpty) {
      await db.update(
        'reading_progress',
        map,
        where: 'manga_id = ?',
        whereArgs: [progress.mangaId],
      );
    } else {
      await db.insert('reading_progress', map);
    }
  }

  /// Delete progress for a manga.
  Future<void> deleteProgress(int mangaId) async {
    final db = await _db.database;
    await db.delete(
      'reading_progress',
      where: 'manga_id = ?',
      whereArgs: [mangaId],
    );
  }

  /// Get all reading progress entries (for sorting by last read).
  Future<Map<int, ReadingProgress>> getAllProgress() async {
    final db = await _db.database;
    final rows = await db.query('reading_progress');
    return Map.fromEntries(
      rows.map((r) {
        final p = ReadingProgress.fromMap(r);
        return MapEntry(p.mangaId, p);
      }),
    );
  }

  /// Get recently read manga IDs, most recent first.
  Future<List<int>> getRecentlyReadIds({int limit = 50}) async {
    final db = await _db.database;
    final rows = await db.query(
      'reading_progress',
      columns: ['manga_id'],
      orderBy: 'last_read_at DESC',
      limit: limit,
    );
    return rows.map((r) => r['manga_id'] as int).toList();
  }
}
