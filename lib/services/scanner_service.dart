import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import '../models/manga_file.dart';
import '../models/remote_source.dart';
import '../repositories/manga_repository.dart';
import '../repositories/tag_repository.dart';
import '../utils/filename_parser.dart';
import 'archive_service.dart';
import 'remote_storage_service.dart';

/// Callback for scan progress.
typedef ScanProgressCallback = void Function(int scanned, int total, String currentFile);

class ScanResult {
  final int added;
  final int updated;
  final int removed;
  final List<String> errors;
  ScanResult({required this.added, required this.updated, required this.removed, required this.errors});
}

class MangaScanItem {
  final String path;
  final String filename;
  final int size;
  final DateTime modified;
  final bool isRemote;
  final int? remoteSourceId;
  MangaScanItem({required this.path, required this.filename, required this.size, required this.modified, required this.isRemote, this.remoteSourceId});
}

class ScannerService {
  final DatabaseHelper _db;
  final MangaRepository _mangaRepo;
  final TagRepository _tagRepo;
  final ArchiveService _archiveService;
  final RemoteStorageService _remoteService;

  ScannerService(this._db, this._mangaRepo, this._tagRepo, this._archiveService, this._remoteService);

  static const _supportedExtensions = {'.zip', '.cbz', '.pdf'};

  /// Get the local cache path for a manga thumbnail.
  static Future<String> getThumbnailPath(String filePath) async {
    final cacheDir = await getTemporaryDirectory();
    final hash = sha256.convert(utf8.encode(filePath)).toString();
    return p.join(cacheDir.path, 'pages', hash, 'page_0.jpg');
  }

  /// Clear the entire thumbnail cache.
  Future<void> clearThumbnailCache() async {
    final cacheDir = await getTemporaryDirectory();
    final pagesDir = Directory(p.join(cacheDir.path, 'pages'));
    if (await pagesDir.exists()) {
      await pagesDir.delete(recursive: true);
    }
  }

  Future<ScanResult> scanAll({
    List<RemoteSource>? remoteSources,
    ScanProgressCallback? onProgress,
  }) async {
    // Local sources
    final sourcesRaw = await _db.getConfig('source_folders');
    final localSources = sourcesRaw != null ? (jsonDecode(sourcesRaw) as List).cast<String>() : <String>[];

    final existingIndex = await _mangaRepo.getIndexedPathsWithModified();
    final foundPaths = <String>{};
    int added = 0;
    int updated = 0;
    final errors = <String>[];

    final allItems = <MangaScanItem>[];

    // Collect local files
    for (final source in localSources) {
      final dir = Directory(source);
      if (!await dir.exists()) continue;
      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (_supportedExtensions.contains(ext)) {
              final stat = await entity.stat();
              allItems.add(MangaScanItem(
                path: entity.path,
                filename: p.basename(entity.path),
                size: stat.size,
                modified: stat.modified,
                isRemote: false,
              ));
            }
          }
        }
      } catch (e) {
        errors.add('Error scanning local $source: $e');
      }
    }

    // Collect remote files
    if (remoteSources != null) {
      for (final source in remoteSources) {
        try {
          final remoteFiles = await _remoteService.listFiles(source);
          for (final f in remoteFiles) {
            final ext = p.extension(f.path).toLowerCase();
            if (_supportedExtensions.contains(ext)) {
              allItems.add(MangaScanItem(
                path: f.path,
                filename: f.name,
                size: f.size,
                modified: f.modified,
                isRemote: true,
                remoteSourceId: source.id,
              ));
            }
          }
        } catch (e) {
          errors.add('Error scanning remote ${source.name}: $e');
        }
      }
    }

    // Process all items
    for (int i = 0; i < allItems.length; i++) {
      final item = allItems[i];
      foundPaths.add(item.path);

      onProgress?.call(i + 1, allItems.length, item.filename);

      try {
        final existingModified = existingIndex[item.path];
        if (existingModified != null && existingModified == item.modified.millisecondsSinceEpoch) {
          continue;
        }

        final parsed = FilenameParser.parse(item.filename);
        final manga = MangaFile(
          path: item.path,
          filename: item.filename,
          title: parsed.title,
          chapter: parsed.chapter,
          ext: parsed.ext,
          size: item.size,
          modifiedAt: item.modified,
          indexedAt: DateTime.now(),
          tagNames: parsed.tags,
          isRemote: item.isRemote,
          remoteSourceId: item.remoteSourceId,
        );

        if (existingModified == null) {
          final id = await _mangaRepo.upsertManga(manga);
          for (final tagName in manga.tagNames) {
            final tagId = await _tagRepo.ensureTag(tagName);
            await _mangaRepo.addTagToManga(id, tagId);
          }
          added++;
        } else {
          await _mangaRepo.upsertManga(manga);
          updated++;
        }
      } catch (e) {
        errors.add('Error processing ${item.path}: $e');
      }
    }

    // Remove missing files from index
    int removed = 0;
    for (final path in existingIndex.keys) {
      if (!foundPaths.contains(path)) {
        final manga = await _mangaRepo.getMangaByPath(path);
        if (manga?.id != null) {
          await _mangaRepo.deleteManga(manga!.id!);
          removed++;
        }
      }
    }

    return ScanResult(added: added, updated: updated, removed: removed, errors: errors);
  }
}
