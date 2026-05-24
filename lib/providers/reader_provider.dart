import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/manga_file.dart';
import '../models/reading_progress.dart';
import '../models/remote_source.dart';
import '../repositories/progress_repository.dart';
import '../repositories/remote_source_repository.dart';
import '../services/archive_service.dart';
import '../services/remote_storage_service.dart';

enum ReaderMode { scroll, flip }

class ReaderProvider extends ChangeNotifier {
  final ProgressRepository _progressRepo;
  final ArchiveService _archiveService;
  final RemoteStorageService _remoteService;
  final RemoteSourceRepository _remoteRepo;

  MangaFile? _currentManga;
  String? _effectivePath; // Local path (could be temp)
  int _currentPage = 0;
  int _totalPages = 0;
  ReaderMode _readerMode = ReaderMode.scroll;
  bool _rtlMode = false;
  String _bgColor = 'black';
  bool _showControls = true;
  bool _isLoading = true;
  int _lastSavedPage = -1;

  // Page cache
  final Map<int, Uint8List> _pageCache = {};

  ReaderProvider(this._progressRepo, this._archiveService, this._remoteService, this._remoteRepo);

  // --- Getters ---
  MangaFile? get currentManga => _currentManga;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  ReaderMode get readerMode => _readerMode;
  bool get rtlMode => _rtlMode;
  String get bgColor => _bgColor;
  bool get showControls => _showControls;
  bool get isLoading => _isLoading;

  Color get backgroundColor {
    switch (_bgColor) {
      case 'white':
        return Colors.white;
      case 'sepia':
        return const Color(0xFFF5E6C8);
      default:
        return Colors.black;
    }
  }

  /// Open a manga for reading.
  Future<void> openManga(MangaFile manga, {ReaderMode? mode, bool? rtl, String? bg}) async {
    _currentManga = manga;
    _isLoading = true;
    _pageCache.clear();
    notifyListeners();

    if (mode != null) _readerMode = mode;
    if (rtl != null) _rtlMode = rtl;
    if (bg != null) _bgColor = bg;

    try {
      _effectivePath = manga.path;

      // Handle Remote File
      if (manga.isRemote && manga.remoteSourceId != null) {
        final source = (await _remoteRepo.getAll())
            .firstWhere((s) => s.id == manga.remoteSourceId);
        
        final tempDir = await getTemporaryDirectory();
        final hash = sha256.convert(utf8.encode(manga.path)).toString();
        final localPath = p.join(tempDir.path, 'remote_cache', '$hash${manga.ext}');
        
        final localFile = File(localPath);
        if (!await localFile.exists()) {
          await localFile.parent.create(recursive: true);
          // "Streaming" simulation: notify that we are downloading
          await _remoteService.downloadFile(source, manga.path, localPath);
        }
        _effectivePath = localPath;
      }

      _totalPages = await _archiveService.getPageCount(_effectivePath!);
      
      final progress = await _progressRepo.getProgress(manga.id!);
      if (progress != null) {
        _currentPage = progress.page;
      } else {
        _currentPage = 0;
      }

      _isLoading = false;
      notifyListeners();

      // Preload first few pages
      _preloadNeighbors();
    } catch (e) {
      print('Error opening manga: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPage(int page) async {
    if (page < 0 || page >= _totalPages) return;
    _currentPage = page;
    notifyListeners();

    _saveProgress();
    _preloadNeighbors();
  }

  Future<Uint8List?> getPage(int index) async {
    if (_pageCache.containsKey(index)) return _pageCache[index];
    if (_effectivePath == null) return null;

    final data = await _archiveService.getPage(_effectivePath!, index);
    if (data != null) {
      _pageCache[index] = data;
    }
    return data;
  }

  void _preloadNeighbors() async {
    if (_effectivePath == null) return;
    // Preload next 3 and prev 1
    for (int i = 1; i <= 3; i++) {
      if (_currentPage + i < _totalPages) getPage(_currentPage + i);
    }
    if (_currentPage > 0) getPage(_currentPage - 1);
  }

  void toggleControls() {
    _showControls = !_showControls;
    notifyListeners();
  }

  void toggleReaderMode() {
    _readerMode = _readerMode == ReaderMode.scroll ? ReaderMode.flip : ReaderMode.scroll;
    notifyListeners();
  }

  void setRtlMode(bool rtl) {
    _rtlMode = rtl;
    notifyListeners();
  }

  void setBgColor(String color) {
    _bgColor = color;
    notifyListeners();
  }

  Future<void> _saveProgress() async {
    if (_currentManga?.id == null || _currentPage == _lastSavedPage) return;

    final progress = ReadingProgress(
      mangaId: _currentManga!.id!,
      page: _currentPage,
      totalPages: _totalPages,
      lastReadAt: DateTime.now(),
    );

    await _progressRepo.saveProgress(progress);
    _lastSavedPage = _currentPage;
  }

  void closeManga() {
    _saveProgress();
    _currentManga = null;
    _effectivePath = null;
    _currentPage = 0;
    _totalPages = 0;
    _pageCache.clear();
    _lastSavedPage = -1;
    notifyListeners();
  }
}
