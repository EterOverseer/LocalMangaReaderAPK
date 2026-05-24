import '../database/database_helper.dart';
import '../models/remote_source.dart';

class RemoteSourceRepository {
  final DatabaseHelper _db;

  RemoteSourceRepository(this._db);

  Future<List<RemoteSource>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('remote_sources');
    return maps.map((m) => RemoteSource.fromMap(m)).toList();
  }

  Future<int> insert(RemoteSource source) async {
    final db = await _db.database;
    return await db.insert('remote_sources', source.toMap());
  }

  Future<void> update(RemoteSource source) async {
    final db = await _db.database;
    await db.update(
      'remote_sources',
      source.toMap(),
      where: 'id = ?',
      whereArgs: [source.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('remote_sources', where: 'id = ?', whereArgs: [id]);
  }
}
