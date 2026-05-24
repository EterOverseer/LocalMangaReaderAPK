import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';
import '../models/manga_file.dart';
import '../models/reading_progress.dart';
import '../repositories/manga_repository.dart';
import '../repositories/tag_repository.dart';
import '../repositories/progress_repository.dart';
import '../services/scanner_service.dart';
import '../services/archive_service.dart';
import '../utils/filename_parser.dart';
import '../services/backup_service.dart';
import '../repositories/remote_source_repository.dart';
import '../models/remote_source.dart';
import '../services/merge_service.dart';

enum SortMode { title, lastRead, dateAdded }

enum ScanState { idle, scanning, done }

class LibraryProvider extends ChangeNotifier {
  final DatabaseHelper _db;
  final MangaRepository _mangaRepo;
  final TagRepository _tagRepo;
  final ProgressRepository _progressRepo;
  final ScannerService _scannerService;
  final ArchiveService _archiveService;
  final BackupService _backupService;
  final RemoteSourceRepository _remoteRepo;
  final MergeService _mergeService;

  List<MangaFile> _allManga = [];
  List<MangaSeries> _series = [];
  List<MangaSeries> _filteredSeries = [];
  Map<int, ReadingProgress> _progressMap = {};
  List<RemoteSource> _remoteSources = [];
  final Map<String, String> _thumbnailPathCache = {};

  String _searchQuery = '';
  SortMode _sortMode = SortMode.title;
  Set<String> _filterTags = {};
  String? _filterSource;
  List<String> _sourceFolders = [];

  ScanState _scanState = ScanState.idle;
  int _scanProgress = 0;
  int _scanTotal = 0;
  String _scanCurrentFile = '';
  String _scanMessage = '';
  bool _isSelectMode = false;
  final Set<MangaSeries> _selectedSeries = {};
  int _activeSourceIndex = -1; // -1 means All Sources

  bool _isProcessing = false;
  double _processProgress = 0.0;
  String _processMessage = '';

  LibraryProvider(
    this._db,
    this._mangaRepo,
    this._tagRepo,
    this._progressRepo,
    this._scannerService,
    this._archiveService,
    this._backupService,
    this._remoteRepo,
    this._mergeService,
  ) {
    _loadState();
  }

  // --- Persistence ---
  Future<File> _getStateFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/library_state.json');
  }

  Future<void> _saveState() async {
    try {
      final file = await _getStateFile();
      final data = {
        'filterTags': _filterTags.toList(),
        'sortMode': _sortMode.index,
        'activeSourceIndex': _activeSourceIndex,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _loadState() async {
    try {
      final file = await _getStateFile();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        _filterTags = Set<String>.from(data['filterTags'] ?? []);
        _sortMode = SortMode.values[data['sortMode'] ?? 0];
        _activeSourceIndex = data['activeSourceIndex'] ?? -1;

        // Update _filterSource based on loaded index
        final folders = await getSourceFolders();
        if (_activeSourceIndex >= 0 && _activeSourceIndex < folders.length) {
          _filterSource = folders[_activeSourceIndex];
        } else {
          _activeSourceIndex = -1;
          _filterSource = null;
        }

        _applyFilters();
        notifyListeners();
      }
    } catch (_) {}
  }

  // --- Getters ---
  List<MangaSeries> get series => _filteredSeries;
  ScanState get scanState => _scanState;
  int get scanProgress => _scanProgress;
  int get scanTotal => _scanTotal;
  String get scanCurrentFile => _scanCurrentFile;
  String get scanMessage => _scanMessage;
  String get searchQuery => _searchQuery;
  SortMode get sortMode => _sortMode;
  Set<String> get filterTags => _filterTags;
  String? get filterSource => _filterSource;
  Map<int, ReadingProgress> get progressMap => _progressMap;
  List<String> get sourceFolders => _sourceFolders;
  int get activeSourceIndex => _activeSourceIndex;
  
  bool get isProcessing => _isProcessing;
  double get processProgress => _processProgress;
  String get processMessage => _processMessage;
  
  bool get isSelectMode => _isSelectMode;
  Set<MangaSeries> get selectedSeries => _selectedSeries;

  /// Initialize the library by loading from database.
  Future<void> initialize({bool autoScan = false}) async {
    _allManga = await _mangaRepo.getAllManga();
    _progressMap = await _progressRepo.getAllProgress();
    _remoteSources = await _remoteRepo.getAll();
    _sourceFolders = await getSourceFolders();
    _buildSeries();
    _applyFilters();
    // Do not notifyListeners yet, let initialize finish
    
    if (autoScan) {
      scan();
    }
    notifyListeners();
  }

  void toggleSelectMode() {
    _isSelectMode = !_isSelectMode;
    if (!_isSelectMode) _selectedSeries.clear();
    notifyListeners();
  }

  void toggleSelection(MangaSeries series) {
    if (_selectedSeries.contains(series)) {
      _selectedSeries.remove(series);
    } else {
      _selectedSeries.add(series);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedSeries.clear();
    notifyListeners();
  }

  /// Scan all source folders for manga.
  Future<ScanResult> scan() async {
    // Request permissions
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
    }

    _scanState = ScanState.scanning;
    _scanProgress = 0;
    _scanTotal = 0;
    _scanCurrentFile = '';
    notifyListeners();

    final result = await _scannerService.scanAll(
      remoteSources: _remoteSources,
      onProgress: (scanned, total, currentFile) {
        _scanProgress = scanned;
        _scanTotal = total;
        _scanCurrentFile = currentFile;
        notifyListeners();
      },
    );

    _scanState = ScanState.done;
    _scanMessage = 'Added: ${result.added}, Updated: ${result.updated}, Removed: ${result.removed}';
    notifyListeners();

    // Refresh library
    await initialize();

    return result;
  }

  /// Set search query and filter.
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  /// Set sort mode.
  void setSortMode(SortMode mode) {
    _sortMode = mode;
    _applyFilters();
    _saveState();
    notifyListeners();
  }

  void toggleTagFilter(String tagName) {
    if (_filterTags.contains(tagName)) {
      _filterTags.remove(tagName);
    } else {
      _filterTags.add(tagName);
    }
    _applyFilters();
    _saveState();
    notifyListeners();
  }

  void clearFilters() {
    _filterTags.clear();
    _searchQuery = '';
    _applyFilters();
    _saveState();
    notifyListeners();
  }

  void setActiveSource(int index) {
    _activeSourceIndex = index;
    if (index == -1) {
      _filterSource = null;
    } else {
      _filterSource = _sourceFolders[index];
    }
    _applyFilters();
    _saveState();
    notifyListeners();
  }

  /// Cycle through source folders for quick swapping.
  Future<void> quickSwapSource() async {
    if (_sourceFolders.isEmpty) return;

    _activeSourceIndex++;
    if (_activeSourceIndex >= _sourceFolders.length) {
      _activeSourceIndex = -1; // All Sources
    }

    _filterSource = _activeSourceIndex == -1 ? null : _sourceFolders[_activeSourceIndex];
    _applyFilters();
    notifyListeners();
  }

  // --- Remote Source Management ---

  List<RemoteSource> get remoteSources => _remoteSources;

  Future<void> addRemoteSource(RemoteSource source) async {
    await _remoteRepo.insert(source);
    _remoteSources = await _remoteRepo.getAll();
    notifyListeners();
  }

  Future<void> removeRemoteSource(int id) async {
    await _remoteRepo.delete(id);
    _remoteSources = await _remoteRepo.getAll();
    notifyListeners();
  }

  /// Get source folders (local).
  Future<List<String>> getSourceFolders() async {
    final raw = await _db.getConfig('source_folders');
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  /// Add a source folder.
  Future<void> addSourceFolder(String path) async {
    final folders = await getSourceFolders();
    if (!folders.contains(path)) {
      folders.add(path);
      await _db.setConfig('source_folders', jsonEncode(folders));
      _sourceFolders = folders;
      notifyListeners();
    }
  }

  /// Remove a source folder.
  Future<void> removeSourceFolder(String path) async {
    final folders = await getSourceFolders();
    folders.remove(path);
    await _db.setConfig('source_folders', jsonEncode(folders));
    _sourceFolders = folders;
    if (_activeSourceIndex >= _sourceFolders.length) _activeSourceIndex = -1;
    notifyListeners();
  }

  /// Global Tag Deletion: Removes tag from DB and renames all associated files.
  Future<void> deleteTagGlobally(String tagName) async {
    _isProcessing = true;
    _processProgress = 0.0;
    _processMessage = 'Preparing to remove tag: $tagName';
    notifyListeners();

    try {
      final affectedManga = _allManga.where((m) => m.tagNames.contains(tagName)).toList();
      int total = affectedManga.length;
      int count = 0;

      for (final manga in affectedManga) {
        _processMessage = 'Renaming: ${manga.filename}';
        _processProgress = count / (total > 0 ? total : 1);
        notifyListeners();

        await removeTagFromManga(manga, tagName, refresh: false);
        count++;
      }

      // Finally remove tag from DB
      await _tagRepo.deleteTagByName(tagName);
      
      _processMessage = 'Successfully removed tag: $tagName';
      _processProgress = 1.0;
      notifyListeners();
      
      await Future.delayed(const Duration(milliseconds: 500));
      await initialize(); // This will refresh the local lists and notify UI
    } catch (e) {
      _processMessage = 'Error: $e';
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Add a tag to a manga file (rename actual file on disk).
  Future<bool> addTagToManga(MangaFile manga, String tagName, {bool refresh = true}) async {
    try {
      final file = File(manga.path);
      if (!await file.exists()) return false;

      final newFilename = FilenameParser.addTag(manga.filename, tagName);
      if (newFilename == manga.filename) return true; // Already has tag

      final dir = file.parent.path;
      final newPath = '$dir${Platform.pathSeparator}$newFilename';
      await file.rename(newPath);

      // Update DB atomically
      if (manga.id != null) {
        final parsed = FilenameParser.parse(newFilename);
        await _mangaRepo.updateMangaPath(manga.id!, newPath, newFilename);
        final tagId = await _tagRepo.ensureTag(tagName.toUpperCase());
        final tagIds = <int>[];
        for (final t in parsed.tags) {
          tagIds.add(await _tagRepo.ensureTag(t));
        }
        await _mangaRepo.setMangaTags(manga.id!, tagIds);
      }

      if (refresh) await initialize();
      return true;
    } catch (e) {
      print('Error adding tag to manga: $e');
      return false;
    }
  }

  /// Remove a tag from a manga file (rename actual file on disk).
  Future<bool> removeTagFromManga(MangaFile manga, String tagName, {bool refresh = true}) async {
    try {
      final file = File(manga.path);
      if (!await file.exists()) return false;

      final newFilename = FilenameParser.removeTag(manga.filename, tagName);
      if (newFilename == manga.filename) return true;

      final dir = file.parent.path;
      final newPath = '$dir${Platform.pathSeparator}$newFilename';
      await file.rename(newPath);

      if (manga.id != null) {
        final parsed = FilenameParser.parse(newFilename);
        await _mangaRepo.updateMangaPath(manga.id!, newPath, newFilename);
        final tagIds = <int>[];
        for (final t in parsed.tags) {
          tagIds.add(await _tagRepo.ensureTag(t));
        }
        await _mangaRepo.setMangaTags(manga.id!, tagIds);
      }

      if (refresh) await initialize();
      return true;
    } catch (e) {
      print('Error removing tag from manga: $e');
      return false;
    }
  }

  /// Update all tags for a series at once and rename physical files.
  Future<void> updateMangaTagsBatch(MangaSeries series, List<String> newTags) async {
    _isProcessing = true;
    _processMessage = 'Updating tags and renaming files...';
    _processProgress = 0.0;
    notifyListeners();
    try {
      await _updateSeriesTags(series, newTags);
      await initialize();
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Add a tag to all currently selected series.
  Future<void> addTagsToSelected(String tagName) async {
    if (_selectedSeries.isEmpty) return;
    
    _isProcessing = true;
    _processMessage = 'Batch adding tag: [$tagName]...';
    _processProgress = 0.0;
    notifyListeners();

    try {
      final list = _selectedSeries.toList();
      for (int i = 0; i < list.length; i++) {
        final series = list[i];
        final currentTags = Set<String>.from(series.tagNames);
        if (!currentTags.contains(tagName)) {
          currentTags.add(tagName);
          // Reuse existing batch logic
          await _updateSeriesTags(series, currentTags.toList());
        }
        _processProgress = (i + 1) / list.length;
        notifyListeners();
      }
      _isSelectMode = false;
      _selectedSeries.clear();
      await initialize();
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Remove a tag from all currently selected series.
  Future<void> removeTagsFromSelected(String tagName) async {
    if (_selectedSeries.isEmpty) return;
    
    _isProcessing = true;
    _processMessage = 'Batch removing tag: [$tagName]...';
    _processProgress = 0.0;
    notifyListeners();

    try {
      final list = _selectedSeries.toList();
      for (int i = 0; i < list.length; i++) {
        final series = list[i];
        final currentTags = Set<String>.from(series.tagNames);
        if (currentTags.contains(tagName)) {
          currentTags.remove(tagName);
          await _updateSeriesTags(series, currentTags.toList());
        }
        _processProgress = (i + 1) / list.length;
        notifyListeners();
      }
      _isSelectMode = false;
      _selectedSeries.clear();
      await initialize();
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Helper to update tags for a series without full initialization in between.
  Future<void> _updateSeriesTags(MangaSeries series, List<String> newTags) async {
    for (final manga in series.chapters) {
      final file = File(manga.path);
      if (!await file.exists()) continue;

      final currentParsed = FilenameParser.parse(manga.filename);
      final newFilename = FilenameParser.compose(
        tags: newTags,
        title: currentParsed.title,
        chapter: currentParsed.chapter,
        ext: currentParsed.ext,
      );

      if (newFilename != manga.filename) {
        final dir = file.parent.path;
        final newPath = '$dir${Platform.pathSeparator}$newFilename';
        await file.rename(newPath);

        if (manga.id != null) {
          await _mangaRepo.updateMangaPath(manga.id!, newPath, newFilename);
          final tagIds = <int>[];
          for (final t in newTags) {
            tagIds.add(await _tagRepo.ensureTag(t.toUpperCase()));
          }
          await _mangaRepo.setMangaTags(manga.id!, tagIds);
        }
      }
    }
  }

  /// Delete a manga from index only (not from disk).
  Future<void> deleteMangaFromIndex(int id) async {
    await _mangaRepo.deleteManga(id);
    await initialize();
  }

  /// Get thumbnail path for a manga.
  Future<String> getThumbnailPath(String filePath) async {
    if (_thumbnailPathCache.containsKey(filePath)) {
      return _thumbnailPathCache[filePath]!;
    }

    final thumbPath = await ScannerService.getThumbnailPath(filePath);
    
    // If thumbnail already exists, return it
    if (await File(thumbPath).exists()) {
      _thumbnailPathCache[filePath] = thumbPath;
      return thumbPath;
    }

    // If it's a local file and thumbnail is missing, try to extract it
    if (await File(filePath).exists()) {
      final bytes = await _archiveService.getThumbnail(filePath);
      if (bytes != null) {
        final file = File(thumbPath);
        if (!await file.parent.exists()) await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
        _thumbnailPathCache[filePath] = thumbPath;
      }
    }
    
    return thumbPath;
  }

  // --- Merge Operations ---
  
  Future<void> mergeSelected(List<MangaFile> chapters, String outputName, bool deleteSources) async {
    _isProcessing = true;
    _processMessage = 'Starting merge...';
    _processProgress = 0.0;
    notifyListeners();

    try {
      await _mergeService.mergeManga(
        mangaList: chapters,
        outputFilename: outputName,
        onProgress: (progress, status) {
          _processProgress = progress;
          _processMessage = status;
          notifyListeners();
        },
      );

      if (deleteSources) {
        _processMessage = 'Cleaning up source files...';
        notifyListeners();
        await _mergeService.deleteSources(chapters);
      }

      _processMessage = 'Merge complete!';
      _processProgress = 1.0;
      notifyListeners();
      
      await Future.delayed(const Duration(seconds: 1));
      await initialize();
    } catch (e) {
      _processMessage = 'Merge failed: $e';
      notifyListeners();
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      _isProcessing = false;
      _isSelectMode = false;
      _selectedSeries.clear();
      notifyListeners();
    }
  }

  // --- Backup & Restore ---

  Future<String> createBackup() => _backupService.createBackup();

  Future<void> restoreBackup(String path) async {
    await _backupService.restoreBackup(path);
    await initialize();
  }

  // --- Private helpers ---

  void _buildSeries() {
    final grouped = groupBy(_allManga, (MangaFile m) => m.title);
    _series = grouped.entries.map((entry) {
      final allTags = <String>{};
      for (final m in entry.value) {
        allTags.addAll(m.tagNames);
      }
      return MangaSeries(
        title: entry.key,
        chapters: entry.value,
        tagNames: allTags.toList()..sort(),
      );
    }).toList();
  }

  void _applyFilters() {
    var result = List<MangaSeries>.from(_series);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((s) => s.title.toLowerCase().contains(query)).toList();
    }

    // Tag filter (OR logic with Ranking)
    if (_filterTags.isNotEmpty) {
      result = result.where((s) {
        final seriesTagsUpper = s.tagNames.map((t) => t.toUpperCase()).toSet();
        return _filterTags.any((tag) => seriesTagsUpper.contains(tag.toUpperCase()));
      }).toList();

      // We will sort by match count as the primary factor if tags are active
    }

    // Source filter
    if (_filterSource != null) {
      result = result.where((s) {
        return s.chapters.any((c) => c.path.startsWith(_filterSource!));
      }).toList();
    }

    // Final Sort with Ranking support
    result.sort((a, b) {
      // 1. If filtering, match count is primary sort
      if (_filterTags.isNotEmpty) {
        int matchA = _filterTags.where((t) => a.tagNames.contains(t)).length;
        int matchB = _filterTags.where((t) => b.tagNames.contains(t)).length;
        if (matchB != matchA) return matchB.compareTo(matchA);
      }

      // 2. Secondary sort by chosen mode
      switch (_sortMode) {
        case SortMode.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case SortMode.lastRead:
          final aProgress = _getLatestProgress(a);
          final bProgress = _getLatestProgress(b);
          if (aProgress == null && bProgress == null) return 0;
          if (aProgress == null) return 1;
          if (bProgress == null) return -1;
          return bProgress.lastReadAt.compareTo(aProgress.lastReadAt);
        case SortMode.dateAdded:
          return b.firstChapter.indexedAt.compareTo(a.firstChapter.indexedAt);
      }
    });

    _filteredSeries = result;
  }

  ReadingProgress? _getLatestProgress(MangaSeries series) {
    ReadingProgress? latest;
    for (final chapter in series.chapters) {
      if (chapter.id != null) {
        final progress = _progressMap[chapter.id];
        if (progress != null) {
          if (latest == null || progress.lastReadAt.isAfter(latest.lastReadAt)) {
            latest = progress;
          }
        }
      }
    }
    return latest;
  }
}
