import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../models/manga_file.dart';
import '../providers/library_provider.dart';
import '../providers/tag_provider.dart';
import '../utils/filename_parser.dart';

class MangaDetailSheet extends StatefulWidget {
  final MangaSeries series;

  const MangaDetailSheet({super.key, required this.series});

  @override
  State<MangaDetailSheet> createState() => _MangaDetailSheetState();
}

class _MangaDetailSheetState extends State<MangaDetailSheet> {
  late Set<String> _selectedTags;
  String _tagSearch = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedTags = Set.from(widget.series.tagNames);
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.read<LibraryProvider>();
    final tp = context.watch<TagProvider>();
    final first = widget.series.firstChapter;
    final file = File(first.path);
    final size = file.existsSync() ? (file.lengthSync() / (1024 * 1024)).toStringAsFixed(2) : '0.00';
    
    final allTags = tp.tags.map((t) => t.name).toList();
    final filteredTags = allTags.where((t) => 
      t.toLowerCase().contains(_tagSearch.toLowerCase()) && !_selectedTags.contains(t)
    ).toList();

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF151525),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(width: 80, height: 110, color: const Color(0xFF1A1A2E),
                  child: FutureBuilder<String>(
                    future: lp.getThumbnailPath(first.path),
                    builder: (ctx, snap) => snap.hasData && File(snap.data!).existsSync()
                      ? Image.file(File(snap.data!), fit: BoxFit.cover)
                      : const Icon(Icons.menu_book_rounded, color: Colors.white10),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.series.title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _infoRow(Icons.description_rounded, p.extension(first.path).toUpperCase().replaceAll('.', '')),
                _infoRow(Icons.sd_storage_rounded, '$size MB'),
                _infoRow(Icons.calendar_today_rounded, _formatDate(first.indexedAt)),
              ])),
            ]),
            const SizedBox(height: 24),
            Text('MANAGE TAGS', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            
            // Searchable Dropdown-like UI
            Container(
              decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(4),
              child: Column(children: [
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search or add tags...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.search, color: Colors.white24, size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _tagSearch = v),
                ),
                if (_tagSearch.isNotEmpty && filteredTags.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredTags.length,
                      itemBuilder: (ctx, i) => ListTile(
                        dense: true,
                        title: Text(filteredTags[i], style: const TextStyle(color: Colors.white70)),
                        onTap: () {
                          setState(() {
                            _selectedTags.add(filteredTags[i]);
                            _tagSearch = '';
                            _searchCtrl.clear();
                          });
                        },
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _selectedTags.map((tag) => Chip(
                label: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: const Color(0xFF6C3CE0).withOpacity(0.2),
                deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white54),
                onDeleted: () => setState(() => _selectedTags.remove(tag)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8), 
                  side: BorderSide(color: const Color(0xFF6C3CE0).withOpacity(0.3))
                ),
              )).toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await lp.updateMangaTagsBatch(widget.series, _selectedTags.toList());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C3CE0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData ic, String txt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(ic, color: Colors.white24, size: 14),
        const SizedBox(width: 6),
        Text(txt, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}
