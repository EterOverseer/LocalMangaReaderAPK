import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service for extracting pages from archive files (ZIP/CBZ) and PDFs.
class ArchiveService {
  static final ArchiveService _instance = ArchiveService._internal();
  factory ArchiveService() => _instance;
  ArchiveService._internal();

  /// Supported image extensions.
  static const _imageExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

  /// Get the cache directory for extracted pages.
  Future<String> _getPageCacheDir(String filePath) async {
    final cacheDir = await getTemporaryDirectory();
    final hash = sha256.convert(utf8.encode(filePath)).toString();
    final dir = Directory(p.join(cacheDir.path, 'pages', hash));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// Get total page count for a file.
  Future<int> getPageCount(String filePath) async {
    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.pdf') {
      return await _getPdfPageCount(filePath);
    } else if (ext == '.zip' || ext == '.cbz') {
      return await _getArchivePageCount(filePath);
    }
    return 0;
  }

  /// Extract a specific page as bytes. Returns null on error.
  Future<Uint8List?> getPage(String filePath, int pageIndex) async {
    final ext = p.extension(filePath).toLowerCase();

    // Check cache first
    final cacheDir = await _getPageCacheDir(filePath);
    final cachedFile = File(p.join(cacheDir, 'page_$pageIndex.jpg'));
    if (await cachedFile.exists()) {
      return await cachedFile.readAsBytes();
    }

    Uint8List? pageData;
    if (ext == '.pdf') {
      pageData = await _getPdfPage(filePath, pageIndex);
    } else if (ext == '.zip' || ext == '.cbz') {
      pageData = await _getArchivePage(filePath, pageIndex);
    }

    // Cache the result
    if (pageData != null) {
      try {
        await cachedFile.writeAsBytes(pageData);
      } catch (_) {
        // Cache write failure is non-critical
      }
    }

    return pageData;
  }

  /// Extract first page as thumbnail bytes.
  Future<Uint8List?> getThumbnail(String filePath) async {
    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.pdf') {
      return await _getPdfThumbnail(filePath);
    }
    return await getPage(filePath, 0);
  }

  Future<Uint8List?> _getPdfThumbnail(String filePath) async {
    try {
      final document = await PdfDocument.openFile(filePath);
      final page = await document.getPage(1);
      final image = await page.render(
        width: page.width * 0.8, // Low res for thumb
        height: page.height * 0.8,
        format: PdfPageImageFormat.jpeg,
        quality: 50,
      );
      await page.close();
      await document.close();
      return image?.bytes;
    } catch (_) {
      return null;
    }
  }

  /// Pre-extract multiple pages for reader performance.
  Future<void> preloadPages(String filePath, int startPage, int count) async {
    final totalPages = await getPageCount(filePath);
    for (int i = startPage; i < startPage + count && i < totalPages; i++) {
      await getPage(filePath, i);
    }
  }

  /// Get all images from an archive (or pages from PDF as images).
  Future<List<ArchiveFile>> getPages(String filePath) async {
    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.pdf') {
      final doc = await PdfDocument.openFile(filePath);
      final List<ArchiveFile> files = [];
      for (int i = 0; i < doc.pagesCount; i++) {
        final page = await doc.getPage(i + 1);
        final image = await page.render(
          width: page.width * 2.0,
          height: page.height * 2.0,
          format: PdfPageImageFormat.jpeg,
        );
        if (image != null) {
          files.add(ArchiveFile('page_${i.toString().padLeft(4, '0')}.jpg', image.bytes.length, image.bytes));
        }
        await page.close();
      }
      await doc.close();
      return files;
    } else {
      final archive = await _getArchive(filePath);
      if (archive == null) return [];
      return _getSortedImageFiles(archive);
    }
  }

  /// Clear cached pages for a specific file.
  Future<void> clearCache(String filePath) async {
    final cacheDir = await _getPageCacheDir(filePath);
    final dir = Directory(cacheDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Clear all page cache.
  Future<void> clearAllCache() async {
    final cacheDir = await getTemporaryDirectory();
    final pagesDir = Directory(p.join(cacheDir.path, 'pages'));
    if (await pagesDir.exists()) {
      await pagesDir.delete(recursive: true);
    }
  }

  // Cache for recently opened documents
  final Map<String, Archive> _archiveCache = {};
  final Map<String, PdfDocument> _pdfCache = {};
  static const int _maxCacheSize = 3;

  Future<Archive?> _getArchive(String filePath) async {
    if (_archiveCache.containsKey(filePath)) {
      return _archiveCache[filePath];
    }
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      
      final bytes = await file.readAsBytes();
      // Use compute to decode in a background isolate
      final archive = await compute(_decodeArchive, bytes);
      
      if (archive != null) {
        if (_archiveCache.length >= _maxCacheSize) {
          _archiveCache.remove(_archiveCache.keys.first);
        }
        _archiveCache[filePath] = archive;
      }
      return archive;
    } catch (e) {
      return null;
    }
  }

  Future<PdfDocument?> _getPdf(String filePath) async {
    if (_pdfCache.containsKey(filePath)) return _pdfCache[filePath];
    try {
      final doc = await PdfDocument.openFile(filePath);
      if (_pdfCache.length >= _maxCacheSize) {
        final firstKey = _pdfCache.keys.first;
        await _pdfCache[firstKey]?.close();
        _pdfCache.remove(firstKey);
      }
      _pdfCache[filePath] = doc;
      return doc;
    } catch (_) {
      return null;
    }
  }

  static Archive? _decodeArchive(Uint8List bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      return null;
    }
  }

  Future<int> _getArchivePageCount(String filePath) async {
    final archive = await _getArchive(filePath);
    if (archive == null) return 0;
    final imageFiles = _getSortedImageFiles(archive);
    return imageFiles.length;
  }

  Future<Uint8List?> _getArchivePage(String filePath, int pageIndex) async {
    final archive = await _getArchive(filePath);
    if (archive == null) return null;
    
    final imageFiles = _getSortedImageFiles(archive);
    if (pageIndex < 0 || pageIndex >= imageFiles.length) return null;
    
    final file = imageFiles[pageIndex];
    return Uint8List.fromList(file.content as List<int>);
  }

  List<ArchiveFile> _getSortedImageFiles(Archive archive) {
    final imageFiles = archive.files.where((f) {
      if (f.isFile) {
        final name = f.name.toLowerCase();
        // Ignore hidden files and system folders
        if (name.startsWith('.') || name.contains('__macosx')) return false;
        final ext = p.extension(name);
        return _imageExtensions.contains(ext);
      }
      return false;
    }).toList();

    imageFiles.sort((a, b) => _naturalCompare(a.name, b.name));
    return imageFiles;
  }

  // --- PDF handling ---

  Future<int> _getPdfPageCount(String filePath) async {
    try {
      final document = await PdfDocument.openFile(filePath);
      final count = document.pagesCount;
      await document.close();
      return count;
    } catch (e) {
      return 0;
    }
  }

  Future<Uint8List?> _getPdfPage(String filePath, int pageIndex) async {
    try {
      final document = await _getPdf(filePath);
      if (document == null || pageIndex < 0 || pageIndex >= document.pagesCount) {
        return null;
      }
      final page = await document.getPage(pageIndex + 1); // 1-indexed
      final image = await page.render(
        width: page.width * 2.2, // Reduced from 3x for speed
        height: page.height * 2.2,
        format: PdfPageImageFormat.jpeg,
        quality: 85, // Balanced quality
      );
      await page.close();
      return image?.bytes;
    } catch (e) {
      return null;
    }
  }

  /// Natural sort comparison for filenames (handles numbers properly).
  int _naturalCompare(String a, String b) {
    final regExp = RegExp(r'(\d+)|(\D+)');
    final matchesA = regExp.allMatches(a).toList();
    final matchesB = regExp.allMatches(b).toList();

    for (int i = 0; i < matchesA.length && i < matchesB.length; i++) {
      final partA = matchesA[i].group(0)!;
      final partB = matchesB[i].group(0)!;

      final numA = int.tryParse(partA);
      final numB = int.tryParse(partB);

      int result;
      if (numA != null && numB != null) {
        result = numA.compareTo(numB);
      } else {
        result = partA.compareTo(partB);
      }
      if (result != 0) return result;
    }
    return matchesA.length.compareTo(matchesB.length);
  }
}
