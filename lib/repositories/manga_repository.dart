import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/manga_file.dart';

class MangaRepository {
  final DatabaseHelper _db;

  MangaRepository(this._db);

  /// Insert or update a manga file record. Returns the ID.
  Future<int> upsertManga(MangaFile manga) async {
    final db = await _db.database;
    // Try to find existing record by path
    final existing = await db.query(
      'manga_files',
      where: 'path = ?',
      whereArgs: [manga.path],
    );

    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      await db.update(
        'manga_files',
        manga.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    } else {
      return await db.insert('manga_files', manga.toMap()..remove('id'));
    }
  }

  /// Get all manga files with their tags.
  Future<List<MangaFile>> getAllManga() async {
    final db = await _db.database;
    final mangaRows = await db.query('manga_files', orderBy: 'title ASC');
    final result = <MangaFile>[];

    for (final row in mangaRows) {
      final tags = await _getTagsForManga(db, row['id'] as int);
      result.add(MangaFile.fromMap(row, tags: tags));
    }
    return result;
  }

  /// Get manga files filtered by title (fuzzy search).
  Future<List<MangaFile>> searchManga(String query) async {
    final db = await _db.database;
    final mangaRows = await db.query(
      'manga_files',
      where: 'title LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'title ASC',
    );
    final result = <MangaFile>[];
    for (final row in mangaRows) {
      final tags = await _getTagsForManga(db, row['id'] as int);
      result.add(MangaFile.fromMap(row, tags: tags));
    }
    return result;
  }

  /// Get manga by ID.
  Future<MangaFile?> getMangaById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'manga_files',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final tags = await _getTagsForManga(db, id);
    return MangaFile.fromMap(rows.first, tags: tags);
  }

  /// Get manga by file path.
  Future<MangaFile?> getMangaByPath(String path) async {
    final db = await _db.database;
    final rows = await db.query(
      'manga_files',
      where: 'path = ?',
      whereArgs: [path],
    );
    if (rows.isEmpty) return null;
    final id = rows.first['id'] as int;
    final tags = await _getTagsForManga(db, id);
    return MangaFile.fromMap(rows.first, tags: tags);
  }

  /// Delete a manga record from the index (not the file).
  Future<void> deleteManga(int id) async {
    final db = await _db.database;
    await db.delete('manga_files', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete manga records whose files no longer exist.
  Future<int> removeStaleEntries(Set<String> existingPaths) async {
    final db = await _db.database;
    final allManga = await db.query('manga_files', columns: ['id', 'path']);
    int removed = 0;
    for (final row in allManga) {
      if (!existingPaths.contains(row['path'] as String)) {
        await db.delete('manga_files', where: 'id = ?', whereArgs: [row['id']]);
        removed++;
      }
    }
    return removed;
  }

  /// Update manga tags association. Replaces all current tags.
  Future<void> setMangaTags(int mangaId, List<int> tagIds) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete('manga_tags', where: 'manga_id = ?', whereArgs: [mangaId]);
      for (final tagId in tagIds) {
        await txn.insert('manga_tags', {
          'manga_id': mangaId,
          'tag_id': tagId,
        });
      }
    });
  }

  /// Add a single tag to a manga.
  Future<void> addTagToManga(int mangaId, int tagId) async {
    final db = await _db.database;
    await db.insert('manga_tags', {
      'manga_id': mangaId,
      'tag_id': tagId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Update path and filename for a manga (after rename).
  Future<void> updateMangaPath(int id, String newPath, String newFilename) async {
    final db = await _db.database;
    await db.update(
      'manga_files',
      {'path': newPath, 'filename': newFilename},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get all indexed paths for incremental scan comparison.
  Future<Map<String, int>> getIndexedPathsWithModified() async {
    final db = await _db.database;
    final rows = await db.query('manga_files', columns: ['path', 'modified_at']);
    return Map.fromEntries(
      rows.map((r) => MapEntry(r['path'] as String, r['modified_at'] as int)),
    );
  }

  /// Get tag names for a given manga ID.
  Future<List<String>> _getTagsForManga(Database db, int mangaId) async {
    final rows = await db.rawQuery('''
      SELECT t.name FROM tags t
      INNER JOIN manga_tags mt ON mt.tag_id = t.id
      WHERE mt.manga_id = ?
      ORDER BY t.name ASC
    ''', [mangaId]);
    return rows.map((r) => r['name'] as String).toList();
  }

  /// Get total count of indexed manga.
  Future<int> getCount() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM manga_files');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
