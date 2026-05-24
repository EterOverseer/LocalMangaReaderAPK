import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/manga_file.dart';
import '../providers/reader_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/reader_scroll.dart';
import '../widgets/reader_pager.dart';

class ReaderScreen extends StatefulWidget {
  final List<MangaFile> playlist;
  final int initialIndex;

  const ReaderScreen({
    super.key,
    required this.playlist,
    required this.initialIndex,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  Timer? _hideTimer;
  late int _currentIndex;
@override
void initState() {
  super.initState();
  _currentIndex = widget.initialIndex;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // DEFER LOADING: Wait for the transition animation to finish (approx 500ms)
  // before starting the heavy loading process.
  Future.delayed(const Duration(milliseconds: 550), () {
    if (mounted) _open();
  });
}

@override
void didUpdateWidget(ReaderScreen oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.playlist != oldWidget.playlist || widget.initialIndex != oldWidget.initialIndex) {
    setState(() => _currentIndex = widget.initialIndex);
    // Reset before opening next chapter
    context.read<ReaderProvider>().closeManga();
    _open(); // Subsequent chapter changes don't need deferring as much
  }
}
Future<void> _open() async {
  final rp = context.read<ReaderProvider>();
  // ...

    final sp = context.read<SettingsProvider>();
    
    rp.closeManga();
    
    await rp.openManga(
      widget.playlist[_currentIndex],
      mode: sp.defaultReaderMode == 'flip' ? ReaderMode.flip : ReaderMode.scroll,
      rtl: sp.rtlMode,
      bg: sp.readerBg,
    );
    _startHideTimer();
  }

  Future<void> _changeChapter(int offset) async {
    final nextIdx = _currentIndex + offset;
    if (nextIdx < 0 || nextIdx >= widget.playlist.length) return;

    setState(() => _currentIndex = nextIdx);
    await _open();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        final rp = context.read<ReaderProvider>();
        if (rp.showControls) rp.toggleControls();
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final rp = context.read<ReaderProvider>();
    rp.closeManga();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<ReaderProvider>();
    final currentManga = widget.playlist[_currentIndex];
    final isStale = rp.currentManga?.path != currentManga.path;

    return Scaffold(
      backgroundColor: rp.backgroundColor,
      body: Stack(children: [
        // Reader content
        GestureDetector(
          onTap: () {
            rp.toggleControls();
            if (rp.showControls) _startHideTimer();
          },
          child: rp.readerMode == ReaderMode.scroll
              ? const ReaderScroll()
              : const ReaderPager(),
        ),
        
        // Loading Overlay
        if (rp.isLoading || isStale)
          Container(
            color: rp.backgroundColor,
            child: Center(
              child: SpinKitPulse(
                color: const Color(0xFF6C3CE0).withOpacity(0.5),
                size: 80.0,
              ),
            ),
          ),

        // UI Controls
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: rp.showControls ? 0 : -100,
          left: 0, right: 0,
          child: _TopBar(
            title: currentManga.chapter ?? currentManga.title,
            onPrev: _currentIndex > 0 ? () => _changeChapter(-1) : null,
            onNext: _currentIndex < widget.playlist.length - 1 ? () => _changeChapter(1) : null,
          ),
        ),
        
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: rp.showControls ? 0 : -180,
          left: 0, right: 0,
          child: _BottomBar(),
        ),
      ]),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _TopBar({required this.title, this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (onPrev != null)
            IconButton(icon: const Icon(Icons.skip_previous_rounded, color: Colors.white), onPressed: onPrev),
          if (onNext != null)
            IconButton(icon: const Icon(Icons.skip_next_rounded, color: Colors.white), onPressed: onNext),
        ]),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rp = context.watch<ReaderProvider>();
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16, left: 24, right: 24, top: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.9), Colors.transparent],
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Page ${rp.currentPage + 1} / ${rp.totalPages}',
              style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              '${((rp.currentPage + 1) / (rp.totalPages > 0 ? rp.totalPages : 1) * 100).toInt()}%',
              style: GoogleFonts.jetBrainsMono(color: const Color(0xFF6C3CE0), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            activeTrackColor: const Color(0xFF6C3CE0),
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            thumbColor: Colors.white,
            overlayColor: const Color(0xFF6C3CE0).withOpacity(0.2),
          ),
          child: Slider(
            value: rp.totalPages > 0 ? rp.currentPage.toDouble() : 0,
            max: rp.totalPages > 1 ? (rp.totalPages - 1).toDouble() : 1,
            onChanged: (v) => rp.setPage(v.round()),
          ),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _CtrlBtn(
            icon: rp.readerMode == ReaderMode.scroll ? Icons.swap_horiz_rounded : Icons.swap_vert_rounded,
            label: rp.readerMode == ReaderMode.scroll ? 'FLIP' : 'SCROLL',
            onTap: rp.toggleReaderMode,
          ),
          _CtrlBtn(
            icon: rp.rtlMode ? Icons.format_textdirection_r_to_l_rounded : Icons.format_textdirection_l_to_r_rounded,
            label: rp.rtlMode ? 'RTL' : 'LTR',
            onTap: () => rp.setRtlMode(!rp.rtlMode),
          ),
          _CtrlBtn(
            icon: Icons.palette_outlined,
            label: 'THEME',
            onTap: () {
              final colors = ['black', 'white', 'sepia'];
              final idx = colors.indexOf(rp.bgColor);
              rp.setBgColor(colors[(idx + 1) % colors.length]);
            },
          ),
        ]),
      ]),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ]),
    );
  }
}
