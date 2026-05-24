import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reader_provider.dart';
import 'page_view_widget.dart';

/// Horizontal page flip reader with optional RTL support.
class ReaderPager extends StatefulWidget {
  const ReaderPager({super.key});

  @override
  State<ReaderPager> createState() => _ReaderPagerState();
}

class _ReaderPagerState extends State<ReaderPager> {
  late PageController _pageController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _initController(ReaderProvider readerProvider) {
    if (!_initialized) {
      _pageController = PageController(initialPage: readerProvider.currentPage);
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final readerProvider = context.watch<ReaderProvider>();
    _initController(readerProvider);

    // Jump to page if provider changed externally (e.g. via slider)
    if (_initialized && _pageController.hasClients) {
      final controllerPage = _pageController.page?.round() ?? readerProvider.currentPage;
      if (controllerPage != readerProvider.currentPage) {
        Future.microtask(() => _pageController.jumpToPage(readerProvider.currentPage));
      }
    }

    final totalPages = readerProvider.totalPages;
    final isRtl = readerProvider.rtlMode;

    return PageView.builder(
      controller: _pageController,
      reverse: isRtl,
      physics: const BouncingScrollPhysics(),
      itemCount: totalPages,
      onPageChanged: (page) {
        readerProvider.setPage(page);
      },
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => readerProvider.toggleControls(),
          child: PageViewWidget(
            pageFuture: readerProvider.getPage(index),
            backgroundColor: readerProvider.backgroundColor,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }
}
