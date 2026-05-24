import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../repositories/manga_repository.dart';
import '../repositories/tag_repository.dart';
import '../repositories/progress_repository.dart';

class BackupService {
  final DatabaseHelper db;
  final MangaRepository mangaRepo;
  final TagRepository tagRepo;
  final ProgressRepository progressRepo;

  BackupService(this.db, this.mangaRepo, this.tagRepo, this.progressRepo);

  Future<String> createBackup() async {
    final now = DateTime.now();
    final formatter = DateFormat('yyyyMMdd_HHmmss');
    final filename = 'manga_reader_backup_${formatter.format(now)}.json';
    
    final downloadsDir = Directory('/storage/emulated/0/Download');
    final backupFile = File(p.join(downloadsDir.path, filename));

    final data = {
      'version': 1,
      'exported_at': now.toIso8601String(),
      'tags': await tagRepo.getAllTagsRaw(),
      'progress': await progressRepo.getAllProgressRaw(),
      'sources': jsonDecode(await db.getConfig('source_folders') ?? '[]'),
      'settings': await db.getAllConfigs(),
    };

    await backupFile.writeAsString(jsonEncode(data));
    return backupFile.path;
  }

  Future<void> restoreBackup(String path) async {
    final file = File(path);
    if (!await file.exists()) throw Exception('Backup file not found');

    final data = jsonDecode(await file.readAsString());
    
    // Restore tags
    final tags = data['tags'] as List;
    for (final t in tags) {
      await tagRepo.upsertTagRaw(t);
    }

    // Restore progress
    final progress = data['progress'] as List;
    for (final pr in progress) {
      await progressRepo.upsertProgressRaw(pr);
    }

    // Restore settings
    final settings = data['settings'] as Map;
    for (final entry in settings.entries) {
      await db.setConfig(entry.key, entry.value.toString());
    }
  }
}
