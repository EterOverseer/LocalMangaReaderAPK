import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/manga_file.dart';
import 'archive_service.dart';

class MergeService {
  final ArchiveService _archiveService;

  MergeService(this._archiveService);

  /// Merges multiple manga files into a single ZIP (CBZ) file.
  /// [mangaList] is the list of manga to merge in the desired order.
  /// [outputFilename] is the name of the resulting file (without extension).
  /// [onProgress] callback for reporting progress (0.0 to 1.0).
  Future<File> mergeManga({
    required List<MangaFile> mangaList,
    required String outputFilename,
    required Function(double progress, String status) onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final workingDir = Directory(p.join(tempDir.path, 'merge_work_${DateTime.now().millisecondsSinceEpoch}'));
    await workingDir.create(recursive: true);

    final archive = Archive();
    int totalFiles = 0;
    int processedFiles = 0;

    try {
      // Phase 1: Extraction & Preparation
      for (int i = 0; i < mangaList.length; i++) {
        final manga = mangaList[i];
        onProgress((i / mangaList.length) * 0.4, 'Extracting: ${manga.title}...');
        
        final pages = await _archiveService.getPages(manga.path);
        totalFiles += pages.length;

        for (int j = 0; j < pages.length; j++) {
          final page = pages[j];
          // Create a unique filename for the page to preserve order
          // Format: [manga_index]_[page_index]_[original_name]
          final newName = '${i.toString().padLeft(4, '0')}_${j.toString().padLeft(4, '0')}_${p.basename(page.name)}';
          archive.addFile(ArchiveFile(newName, page.content.length, page.content));
          
          processedFiles++;
          // We'll report progress based on files added to archive
          // Split 40% extraction, 60% compression
        }
      }

      // Phase 2: Compression
      onProgress(0.5, 'Compressing into new archive...');
      final encoder = ZipEncoder();
      
      // Since ZipEncoder in 'archive' package doesn't natively support progress for the whole operation easily,
      // we just report a "working" state.
      final outputBytes = encoder.encode(archive);
      
      if (outputBytes == null) throw Exception('Failed to encode archive');

      // Save to same directory as the first manga in the list
      final firstMangaFile = File(mangaList.first.path);
      final outputDir = firstMangaFile.parent.path;
      final outputPath = p.join(outputDir, '$outputFilename.cbz');
      
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(outputBytes);

      onProgress(1.0, 'Done!');
      return outputFile;
    } finally {
      // Cleanup temp working dir
      if (await workingDir.exists()) {
        await workingDir.delete(recursive: true);
      }
    }
  }

  /// Deletes source files.
  Future<void> deleteSources(List<MangaFile> mangaList) async {
    for (final manga in mangaList) {
      final file = File(manga.path);
      if (await file.exists()) {
        await file.delete();
      }
      // Note: We might also want to delete the folder if it's empty, 
      // but typically manga are in a shared folder.
    }
  }
}
