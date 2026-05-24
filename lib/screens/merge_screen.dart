import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/manga_file.dart';

class MergeScreen extends StatefulWidget {
  final List<MangaFile> initialChapters;

  const MergeScreen({super.key, required this.initialChapters});

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  late List<MangaFile> _chapters;
  final TextEditingController _nameController = TextEditingController();
  bool _deleteSources = false;

  @override
  void initState() {
    super.initState();
    _chapters = List.from(widget.initialChapters);
    // Suggest a name based on the first item
    if (_chapters.isNotEmpty) {
      _nameController.text = '${_chapters.first.title}_Merged';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Merge Manga', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Output Filename', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.54))),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Enter name...',
                        hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.24)),
                        border: InputBorder.none,
                        suffixText: '.cbz',
                        suffixStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.24)),
                      ),
                    ),
                    Divider(color: theme.dividerColor.withOpacity(0.05)),
                    Row(
                      children: [
                        const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Delete source files after merge', 
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 14)),
                        ),
                        Switch(
                          value: _deleteSources,
                          onChanged: (v) => setState(() => _deleteSources = v),
                          activeColor: theme.primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.drag_handle_rounded, color: colorScheme.onSurface.withOpacity(0.24), size: 16),
                const SizedBox(width: 8),
                Text('Drag to reorder', 
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.24))),
                const Spacer(),
                Text('${_chapters.length} items', 
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.24))),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _chapters.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = _chapters.removeAt(oldIndex);
                  _chapters.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final manga = _chapters[index];
                return ListTile(
                  key: ValueKey(manga.path),
                  leading: Icon(Icons.menu_book_rounded, color: theme.primaryColor),
                  title: Text(manga.title, 
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(manga.chapter ?? 'No Chapter', 
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.38), fontSize: 12)),
                  trailing: Icon(Icons.drag_indicator_rounded, color: colorScheme.onSurface.withOpacity(0.24)),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: () {
                if (_nameController.text.trim().isEmpty) return;
                Navigator.pop(context, {
                  'chapters': _chapters,
                  'name': _nameController.text.trim(),
                  'delete': _deleteSources,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Start Merge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
