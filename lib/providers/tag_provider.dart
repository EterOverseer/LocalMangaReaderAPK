import 'dart:io';
import 'package:flutter/material.dart';
import '../models/tag.dart';
import '../models/manga_file.dart';
import '../repositories/tag_repository.dart';
import '../repositories/manga_repository.dart';
import '../utils/filename_parser.dart';

class TagProvider extends ChangeNotifier {
  final TagRepository _tagRepo;
  final MangaRepository _mangaRepo;

  List<Tag> _tags = [];

  TagProvider(this._tagRepo, this._mangaRepo);

  List<Tag> get tags => _tags;

  /// Load all tags from database.
  Future<void> loadTags() async {
    _tags = await _tagRepo.getAllTags();
    notifyListeners();
  }

  /// Get tag by name.
  Tag? getTagByName(String name) {
    try {
      return _tags.firstWhere((t) => t.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Create a new tag.
  Future<Tag?> createTag(String name, String color, String label) async {
    try {
      final cleanName = name.trim().toUpperCase();
      if (cleanName.isEmpty) return null;
      
      final existing = getTagByName(cleanName);
      if (existing != null) return existing;

      final id = await _tagRepo.insertTag(Tag(
        name: cleanName,
        color: color,
        label: label,
        createdAt: DateTime.now(),
      ));
      
      await loadTags();
      return _tags.firstWhere((t) => t.id == id);
    } catch (e) {
      debugPrint('Error creating tag: $e');
      return null;
    }
  }

  /// Update tag color and label.
  Future<void> updateTag(int id, {String? color, String? label}) async {
    await _tagRepo.updateTag(id, color: color, label: label);
    await loadTags();
  }

  /// Rename a tag (also renames all affected files on disk).
  Future<bool> renameTag(int tagId, String oldName, String newName) async {
    try {
      // Find all manga with this tag
      final mangaIds = await _tagRepo.getMangaIdsWithTag(tagId);

      // Rename files on disk
      for (final mangaId in mangaIds) {
        final manga = await _mangaRepo.getMangaById(mangaId);
        if (manga == null) continue;

        final file = File(manga.path);
        if (!await file.exists()) continue;

        final newFilename = FilenameParser.renameTag(manga.filename, oldName, newName);
        if (newFilename == manga.filename) continue;

        final dir = file.parent.path;
        final newPath = '$dir${Platform.pathSeparator}$newFilename';
        await file.rename(newPath);

        // Update DB
        final parsed = FilenameParser.parse(newFilename);
        await _mangaRepo.updateMangaPath(mangaId, newPath, newFilename);
      }

      // Rename tag in DB
      await _tagRepo.renameTag(tagId, newName.toUpperCase());
      await loadTags();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a tag (also removes from all filenames on disk).
  Future<bool> deleteTag(int tagId, String tagName) async {
    try {
      // Find all manga with this tag
      final mangaIds = await _tagRepo.getMangaIdsWithTag(tagId);

      // Remove tag from filenames
      for (final mangaId in mangaIds) {
        final manga = await _mangaRepo.getMangaById(mangaId);
        if (manga == null) continue;

        final file = File(manga.path);
        if (!await file.exists()) continue;

        final newFilename = FilenameParser.removeTag(manga.filename, tagName);
        if (newFilename == manga.filename) continue;

        final dir = file.parent.path;
        final newPath = '$dir${Platform.pathSeparator}$newFilename';
        await file.rename(newPath);

        // Update DB
        await _mangaRepo.updateMangaPath(mangaId, newPath, newFilename);
      }

      // Delete tag from DB
      await _tagRepo.deleteTag(tagId);
      await loadTags();
      return true;
    } catch (e) {
      return false;
    }
  }
}
