import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reader_provider.dart';
import 'page_view_widget.dart';

/// Vertical continuous scroll reader (webtoon style).
class ReaderScroll extends StatefulWidget {
  const ReaderScroll({super.key});

  @override
  State<ReaderScroll> createState() => _ReaderScrollState();
}

class _ReaderScrollState extends State<ReaderScroll> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final readerProvider = context.read<ReaderProvider>();

    // Estimate page based on scroll position to update current page index
    double scrollOffset = _scrollController.offset;
    final totalPages = readerProvider.totalPages;
    final maxScroll = _scrollController.position.maxScrollExtent;

    if (maxScroll > 0) {
      final progress = scrollOffset / maxScroll;
      final estimatedPage = (progress * (totalPages - 1)).round();
      if (estimatedPage != readerProvider.currentPage) {
        // Use a method that doesn't trigger a full rebuild if possible, 
        // but setPage currently calls notifyListeners.
        // To avoid flicker, we need the items to be stable.
        readerProvider.setPage(estimatedPage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only listen to totalPages changes for the list structure
    final totalPages = context.select<ReaderProvider, int>((p) => p.totalPages);
    
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: totalPages,
      itemBuilder: (context, index) {
        return _ScrollPageItem(index: index);
      },
    );
  }
}

class _ScrollPageItem extends StatefulWidget {
  final int index;
  const _ScrollPageItem({required this.index});

  @override
  State<_ScrollPageItem> createState() => _ScrollPageItemState();
}

class _ScrollPageItemState extends State<_ScrollPageItem> with AutomaticKeepAliveClientMixin {
  late Future<Uint8List?> _pageFuture;

  @override
  void initState() {
    super.initState();
    _pageFuture = context.read<ReaderProvider>().getPage(widget.index);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bgColor = context.select<ReaderProvider, Color>((p) => p.backgroundColor);
    
    return SizedBox(
      width: double.infinity,
      child: PageViewWidget(
        pageFuture: _pageFuture,
        backgroundColor: bgColor,
        fit: BoxFit.fitWidth,
      ),
    );
  }
}
