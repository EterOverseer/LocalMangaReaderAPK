import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/manga_file.dart';
import '../models/reading_progress.dart';
import '../providers/library_provider.dart';
import '../providers/tag_provider.dart';
import '../services/scanner_service.dart';
import '../widgets/tag_chip.dart';
import 'reader_screen.dart';

class SeriesScreen extends StatelessWidget {
  final MangaSeries series;
  const SeriesScreen({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TagProvider>();
    final lp = context.watch<LibraryProvider>();
    final chapters = List<MangaFile>.from(series.chapters)
      ..sort((a, b) => (a.chapter ?? '').compareTo(b.chapter ?? ''));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: const Color(0xFF1A1A2E),
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: FlexibleSpaceBar(
            title: Text(series.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            background: Stack(fit: StackFit.expand, children: [
              Hero(
                tag: 'cover_${series.firstChapter.path}',
                child: _CoverImage(filePath: series.firstChapter.path),
              ),
              Container(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, const Color(0xFF0F0F1A).withOpacity(0.9)]))),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (series.tagNames.isNotEmpty) Wrap(spacing: 6, runSpacing: 4,
              children: series.tagNames.map((n) => TagChip(
                tagName: n, tagData: tp.getTagByName(n), fontSize: 11)).toList()),
            const SizedBox(height: 12),
            Text('${chapters.length} chapter${chapters.length > 1 ? 's' : ''}',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
            const Divider(color: Color(0xFF2A2A3E), height: 24),
          ]),
        )),
        SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
          final ch = chapters[i];
          final progress = ch.id != null ? lp.progressMap[ch.id] : null;
          final isRead = progress?.isRead ?? false;
          return _ChapterTile(
            manga: ch, progress: progress, isRead: isRead,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ReaderScreen(key: UniqueKey(), playlist: chapters, initialIndex: i))),
          );
        }, childCount: chapters.length)),
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ]),
    );
  }
}

class _CoverImage extends StatefulWidget {
  final String filePath;
  const _CoverImage({required this.filePath});
  @override
  State<_CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<_CoverImage> {
  String? _path;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final p = await ScannerService.getThumbnailPath(widget.filePath);
    if (mounted) setState(() => _path = p);
  }
  @override
  Widget build(BuildContext context) {
    if (_path != null && File(_path!).existsSync()) {
      return Image.file(File(_path!), fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _ph());
    }
    return _ph();
  }
  Widget _ph() => Container(color: const Color(0xFF2A2A3E),
    child: const Center(child: Icon(Icons.menu_book_rounded, color: Color(0xFF6C3CE0), size: 64)));
}

class _ChapterTile extends StatelessWidget {
  final MangaFile manga;
  final ReadingProgress? progress;
  final bool isRead;
  final VoidCallback onTap;
  const _ChapterTile({required this.manga, this.progress, required this.isRead, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: isRead ? const Color(0xFF6C3CE0).withOpacity(0.2) : const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(
          isRead ? Icons.check_rounded : Icons.book_rounded,
          color: isRead ? const Color(0xFF6C3CE0) : Colors.white38, size: 18),
      ),
      title: Text(manga.chapter ?? manga.title,
        style: TextStyle(color: isRead ? Colors.white54 : Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: progress != null
        ? Text('Page ${progress!.page + 1} / ${progress!.totalPages}',
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11))
        : null,
      trailing: progress != null
        ? SizedBox(width: 32, height: 32,
            child: CircularProgressIndicator(
              value: progress!.progressPercent, strokeWidth: 2.5,
              backgroundColor: const Color(0xFF2A2A3E),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF6C3CE0))))
        : const Icon(Icons.chevron_right, color: Colors.white24),
    );
  }
}
