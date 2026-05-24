import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../models/manga_file.dart';
import '../providers/library_provider.dart';
import '../providers/tag_provider.dart';
import 'tag_chip.dart';

class MangaCard extends StatelessWidget {
  final MangaSeries series;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const MangaCard({
    super.key,
    required this.series,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.cardTheme.color,
      shape: theme.cardTheme.shape,
      clipBehavior: Clip.antiAlias,
      elevation: theme.cardTheme.elevation,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        splashColor: theme.primaryColor.withOpacity(0.3),
        highlightColor: theme.primaryColor.withOpacity(0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thumbnail with fixed aspect ratio
            AspectRatio(
              aspectRatio: 0.7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'cover_${series.firstChapter.path}',
                    child: _ThumbnailWidget(filePath: series.firstChapter.path),
                  ),
                  // Gradient overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Chapter count badge
                  if (!series.isStandalone)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${series.chapterCount} ch',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Selection Overlay
                  if (isSelected)
                    Container(
                      color: theme.primaryColor.withOpacity(0.4),
                      child: const Center(
                        child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 40),
                      ),
                    ),
                  // Tags at bottom of image
                  if (series.tagNames.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      right: 6,
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: series.tagNames.take(2).map((tagName) {
                          return TagChip(
                            tagName: tagName,
                            fontSize: 9,
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Text(
                series.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ) ?? GoogleFonts.inter(
                  color: theme.colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailWidget extends StatefulWidget {
  final String filePath;

  const _ThumbnailWidget({required this.filePath});

  @override
  State<_ThumbnailWidget> createState() => _ThumbnailWidgetState();
}

class _ThumbnailWidgetState extends State<_ThumbnailWidget> {
  String? _thumbPath;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final libraryProvider = context.read<LibraryProvider>();
    final path = await libraryProvider.getThumbnailPath(widget.filePath);
    
    if (mounted && _thumbPath != path) {
      setState(() {
        _thumbPath = path;
        _loaded = true;
      });
    } else if (mounted && !_loaded) {
      setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_loaded) {
      return Shimmer.fromColors(
        baseColor: theme.brightness == Brightness.dark ? const Color(0xFF1E1E2E) : Colors.grey[200]!,
        highlightColor: theme.brightness == Brightness.dark ? const Color(0xFF2A2A3E) : Colors.grey[100]!,
        child: Container(color: Colors.white),
      );
    }

    if (_thumbPath != null && File(_thumbPath!).existsSync()) {
      return Image.file(
        File(_thumbPath!),
        fit: BoxFit.cover,
        cacheWidth: 400,
        filterQuality: FilterQuality.high,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: child,
          );
        },
        errorBuilder: (_, __, ___) => const _Placeholder(),
      );
    }

    return const _Placeholder();
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.brightness == Brightness.dark ? const Color(0xFF2A2A3E) : Colors.grey[100],
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          color: theme.primaryColor.withOpacity(0.5),
          size: 40,
        ),
      ),
    );
  }
}
