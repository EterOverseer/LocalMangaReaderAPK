import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/tag.dart';

class TagRepository {
  final DatabaseHelper _db;

  TagRepository(this._db);

  /// Get all tags.
  Future<List<Tag>> getAllTags() async {
    final db = await _db.database;
    final rows = await db.query('tags', orderBy: 'name ASC');
    return rows.map((r) => Tag.fromMap(r)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllTagsRaw() async {
    final db = await _db.database;
    return await db.query('tags');
  }

  Future<void> upsertTagRaw(Map<String, dynamic> data) async {
    final db = await _db.database;
    await db.insert('tags', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get tag by name.
  Future<Tag?> getTagByName(String name) async {
    final db = await _db.database;
    final rows = await db.query(
      'tags',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (rows.isEmpty) return null;
    return Tag.fromMap(rows.first);
  }

  /// Get tag by ID.
  Future<Tag?> getTagById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return Tag.fromMap(rows.first);
  }

  /// Insert a new tag. Returns the ID.
  Future<int> insertTag(Tag tag) async {
    final db = await _db.database;
    return await db.insert('tags', tag.toMap()..remove('id'));
  }

  /// Ensure a tag exists; create if it doesn't. Returns the tag ID.
  Future<int> ensureTag(String name, {String color = '#808080', String label = ''}) async {
    final existing = await getTagByName(name);
    if (existing != null) return existing.id!;
    return await insertTag(Tag(
      name: name,
      color: color,
      label: label,
      createdAt: DateTime.now(),
    ));
  }

  /// Update a tag's color and label.
  Future<void> updateTag(int id, {String? color, String? label}) async {
    final db = await _db.database;
    final updates = <String, dynamic>{};
    if (color != null) updates['color'] = color;
    if (label != null) updates['label'] = label;
    if (updates.isNotEmpty) {
      await db.update('tags', updates, where: 'id = ?', whereArgs: [id]);
    }
  }

  /// Rename a tag.
  Future<void> renameTag(int id, String newName) async {
    final db = await _db.database;
    await db.update('tags', {'name': newName}, where: 'id = ?', whereArgs: [id]);
  }

  /// Delete a tag and all associations.
  Future<void> deleteTag(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete('manga_tags', where: 'tag_id = ?', whereArgs: [id]);
      await txn.delete('tags', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Delete a tag by name.
  Future<void> deleteTagByName(String name) async {
    final tag = await getTagByName(name);
    if (tag != null) {
      await deleteTag(tag.id!);
    }
  }

  /// Get manga IDs that have a specific tag.
  Future<List<int>> getMangaIdsWithTag(int tagId) async {
    final db = await _db.database;
    final rows = await db.query(
      'manga_tags',
      columns: ['manga_id'],
      where: 'tag_id = ?',
      whereArgs: [tagId],
    );
    return rows.map((r) => r['manga_id'] as int).toList();
  }

  /// Get tags for a specific manga.
  Future<List<Tag>> getTagsForManga(int mangaId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT t.* FROM tags t
      INNER JOIN manga_tags mt ON mt.tag_id = t.id
      WHERE mt.manga_id = ?
      ORDER BY t.name ASC
    ''', [mangaId]);
    return rows.map((r) => Tag.fromMap(r)).toList();
  }
}
