import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:animations/animations.dart';

import '../models/manga_file.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tag_provider.dart';
import '../widgets/manga_card.dart';
import '../widgets/manga_detail_sheet.dart';
import 'series_screen.dart';
import 'reader_screen.dart';
import 'merge_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isScrollingDown = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (!_isScrollingDown) setState(() => _isScrollingDown = true);
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (_isScrollingDown) setState(() => _isScrollingDown = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LibraryProvider>();
    final tp = context.watch<TagProvider>();
    final sp = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () => lp.scan(),
        color: Theme.of(context).primaryColor,
        displacement: 100,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildSliverAppBar(lp, tp, sp),
            
            if (lp.scanState == ScanState.scanning)
              SliverToBoxAdapter(child: _scanIndicator(lp)),
            
            if (lp.series.isEmpty && lp.scanState != ScanState.scanning)
              SliverFillRemaining(hasScrollBody: false, child: _emptyState(lp))
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverAlignedGrid.count(
                  crossAxisCount: sp.gridColumns,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  itemCount: lp.series.length,
                  itemBuilder: (context, index) {
                    final series = lp.series[index];
                    return _buildMangaItem(series, lp);
                  },
                ),
              ),
            
            // Padding for FAB
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: AnimatedScale(
        scale: _isScrollingDown ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: FloatingActionButton(
          onPressed: () => lp.toggleSelectMode(),
          backgroundColor: lp.isSelectMode ? Colors.redAccent : Theme.of(context).primaryColor,
          child: Icon(lp.isSelectMode ? Icons.close_rounded : Icons.checklist_rounded, color: Colors.white),
        ),
      ),
      extendBodyBehindAppBar: true,
      bottomSheet: lp.isProcessing ? _buildProgressBottomSheet(lp) : null,
    );
  }

  Widget _buildMangaItem(MangaSeries series, LibraryProvider lp) {
    return OpenContainer(
      closedElevation: 0,
      closedColor: Colors.transparent,
      openColor: Theme.of(context).scaffoldBackgroundColor,
      transitionDuration: const Duration(milliseconds: 500),
      openBuilder: (context, _) => series.isStandalone 
          ? ReaderScreen(key: UniqueKey(), playlist: series.chapters, initialIndex: 0)
          : SeriesScreen(key: UniqueKey(), series: series),
      closedBuilder: (context, openContainer) => MangaCard(
        series: series,
        isSelected: lp.selectedSeries.contains(series),
        onTap: () {
          if (lp.isSelectMode) {
            lp.toggleSelection(series);
          } else {
            openContainer();
          }
        },
        onLongPress: () {
          if (lp.isSelectMode) {
            lp.toggleSelection(series);
          } else {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => MangaDetailSheet(series: series),
            );
          }
        },
      ),
    );
  }

  Widget _buildSliverAppBar(LibraryProvider lp, TagProvider tp, SettingsProvider sp) {
    return SliverAppBar(
      expandedHeight: 130,
      floating: true,
      pinned: true,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor?.withOpacity(0.9) ?? Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
      elevation: 0,
      title: lp.isSelectMode ? _selectionTitle(lp) : _appTitle(lp),
      flexibleSpace: FlexibleSpaceBar(
        background: Column(
          children: [
            const SizedBox(height: 85),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _showSearch ? _searchBar(lp) : _tagStrip(lp, tp),
            ),
          ],
        ),
      ),
      actions: lp.isSelectMode ? _selectionActions(lp, tp) : _defaultActions(lp, tp, sp),
    );
  }

  Widget _appTitle(LibraryProvider lp) {
    return PopupMenuButton<int>(
      offset: const Offset(0, 40),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (idx) => lp.setActiveSource(idx),
      itemBuilder: (ctx) {
        final items = <PopupMenuEntry<int>>[
          PopupMenuItem(
            value: -1,
            child: Row(children: [
              Icon(Icons.library_books_rounded, color: lp.activeSourceIndex == -1 ? Theme.of(context).primaryColor : Colors.grey, size: 20),
              const SizedBox(width: 10),
              const Text('All Sources'),
            ]),
          ),
          const PopupMenuDivider(),
        ];
        for (int i = 0; i < lp.sourceFolders.length; i++) {
          items.add(PopupMenuItem(
            value: i,
            child: Text(lp.sourceFolders[i], maxLines: 1, overflow: TextOverflow.ellipsis),
          ));
        }
        return items;
      },
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // App Logo
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/logo_mangaReader.jpg', width: 32, height: 32, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            lp.activeSourceIndex == -1 ? 'Local Library' : p.basename(lp.sourceFolders[lp.activeSourceIndex]),
            style: Theme.of(context).appBarTheme.titleTextStyle,
            overflow: TextOverflow.ellipsis),
        ),
        Icon(Icons.arrow_drop_down, color: Theme.of(context).appBarTheme.iconTheme?.color?.withOpacity(0.5)),
      ]),
    );
  }

  Widget _selectionTitle(LibraryProvider lp) {
    return Text('${lp.selectedSeries.length} Selected', style: GoogleFonts.inter(fontWeight: FontWeight.bold));
  }

  List<Widget> _defaultActions(LibraryProvider lp, TagProvider tp, SettingsProvider sp) {
    return [
      // Theme Toggle Button
      IconButton(
        icon: Icon(sp.themeMode == ThemeMode.light ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
        onPressed: () => sp.toggleTheme(),
      ),
      IconButton(
        icon: Icon(_showSearch ? Icons.close : Icons.search),
        onPressed: () {
          setState(() {
            _showSearch = !_showSearch;
            if (!_showSearch) {
              _searchController.clear();
              lp.setSearchQuery('');
            }
          });
        },
      ),
      PopupMenuButton<SortMode>(
        icon: const Icon(Icons.sort_rounded),
        color: Theme.of(context).cardColor,
        onSelected: lp.setSortMode,
        itemBuilder: (_) => [
          _sortItem(SortMode.title, 'Title', Icons.sort_by_alpha, lp.sortMode),
          _sortItem(SortMode.lastRead, 'Last Read', Icons.schedule, lp.sortMode),
          _sortItem(SortMode.dateAdded, 'Date Added', Icons.date_range, lp.sortMode),
        ],
      ),
    ];
  }

  List<Widget> _selectionActions(LibraryProvider lp, TagProvider tp) {
    return [
      IconButton(
        icon: const Icon(Icons.merge_type_rounded, color: Colors.white),
        tooltip: 'Merge Selected',
        onPressed: () => _handleMerge(lp),
      ),
      IconButton(
        icon: const Icon(Icons.label_outline_rounded, color: Colors.white),
        onPressed: () => _showBatchTagAction(lp, tp, true),
      ),
      IconButton(
        icon: const Icon(Icons.label_off_rounded, color: Colors.white),
        onPressed: () => _showBatchTagAction(lp, tp, false),
      ),
    ];
  }

  PopupMenuItem<SortMode> _sortItem(SortMode m, String l, IconData ic, SortMode cur) {
    final on = m == cur;
    return PopupMenuItem(value: m, child: Row(children: [
      Icon(ic, color: on ? Theme.of(context).primaryColor : Colors.grey, size: 18),
      const SizedBox(width: 8),
      Text(l, style: TextStyle(
        color: on ? Theme.of(context).primaryColor : null,
        fontWeight: on ? FontWeight.bold : FontWeight.normal)),
    ]));
  }

  Widget _searchBar(LibraryProvider p) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search manga...',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (val) => p.setSearchQuery(val),
      ),
    );
  }

  Widget _tagStrip(LibraryProvider p, TagProvider tp) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _tagChip('All', null, p.filterTags.isEmpty, () => p.clearFilters()),
          const SizedBox(width: 8),
          ...tp.tags.map((t) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _tagChip(t.name, t.colorValue, p.filterTags.any((ft) => ft.toUpperCase() == t.name.toUpperCase()), () => p.toggleTagFilter(t.name)),
          )),
        ],
      ),
    );
  }

  Widget _tagChip(String label, Color? color, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            if (color != null) ...[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : null,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanIndicator(LibraryProvider p) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor)),
              ),
              const SizedBox(width: 12),
              Text('Scanning...', style: GoogleFonts.inter(fontSize: 12)),
              const Spacer(),
              Text('${p.scanProgress}/${p.scanTotal}', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Theme.of(context).primaryColor)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.scanTotal > 0 ? p.scanProgress / p.scanTotal : 0,
              minHeight: 2,
              backgroundColor: Colors.grey.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(LibraryProvider p) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.auto_stories_outlined, size: 64, color: Colors.grey.withOpacity(0.3)),
      const SizedBox(height: 16),
      Text(p.filterTags.isNotEmpty || p.searchQuery.isNotEmpty ? 'No matches found' : 'Your library is empty', 
        style: GoogleFonts.inter(color: Colors.grey, fontSize: 16)),
      const SizedBox(height: 24),
      if (p.filterTags.isNotEmpty || p.searchQuery.isNotEmpty)
        TextButton(onPressed: p.clearFilters, child: const Text('Clear Filters'))
      else
        ElevatedButton(
          onPressed: _showAddSourceDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Add Source'),
        ),
    ]));
  }

  void _showAddSourceDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Source'),
      content: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: 'Folder path',
          filled: true, fillColor: Colors.grey.withOpacity(0.05),
          suffixIcon: IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () async {
              String? path = await FilePicker.platform.getDirectoryPath();
              if (path != null) ctrl.text = path;
            },
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (ctrl.text.isNotEmpty) {
              await context.read<LibraryProvider>().addSourceFolder(ctrl.text);
              Navigator.pop(ctx);
              context.read<LibraryProvider>().scan();
            }
          },
          child: const Text('Add'),
        ),
      ],
    ));
  }

  Widget _buildProgressBottomSheet(LibraryProvider lp) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 16),
              Expanded(child: Text(lp.processMessage, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: lp.processProgress),
        ],
      ),
    );
  }

  Future<void> _handleMerge(LibraryProvider lp) async {
    if (lp.selectedSeries.isEmpty) return;

    final List<MangaFile> allChapters = [];
    for (final series in lp.selectedSeries) {
      allChapters.addAll(series.chapters);
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MergeScreen(initialChapters: allChapters)),
    );

    if (result != null && result is Map) {
      final chapters = result['chapters'] as List<MangaFile>;
      final name = result['name'] as String;
      final delete = result['delete'] as bool;
      
      lp.mergeSelected(chapters, name, delete);
    }
  }

  void _showBatchTagAction(LibraryProvider lp, TagProvider tp, bool isAdd) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        String query = '';
        final filtered = tp.tags.map((t) => t.name).where((n) => n.contains(query.toUpperCase())).toList();
        
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isAdd ? 'Add Tag' : 'Remove Tag', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(hintText: 'Search tags...'),
                onChanged: (v) => setS(() => query = v),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => ListTile(
                    title: Text(filtered[i]),
                    onTap: () {
                      Navigator.pop(context);
                      isAdd ? lp.addTagsToSelected(filtered[i]) : lp.removeTagsFromSelected(filtered[i]);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
