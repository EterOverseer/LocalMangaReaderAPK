import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/tag_provider.dart';
import '../../providers/library_provider.dart';
import '../library_screen.dart';

class TagMgrTab extends StatefulWidget {
  const TagMgrTab({super.key});

  @override
  State<TagMgrTab> createState() => _TagMgrTabState();
}

class _TagMgrTabState extends State<TagMgrTab> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TagProvider>();
    final lp = context.watch<LibraryProvider>();
    
    final filteredTags = tp.tags.where((t) => 
      t.name.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Categories', 
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            onPressed: () async {
              await tp.loadTags();
              await lp.initialize();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF6C3CE0)),
            onPressed: () => _showAddTagDialog(context, tp),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search tags...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.search, color: Colors.white24, size: 20),
                    filled: true,
                    fillColor: const Color(0xFF1A1A2E),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              Expanded(
                child: filteredTags.isEmpty
                    ? _buildEmpty(context)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredTags.length,
                        itemBuilder: (context, index) {
                          final tag = filteredTags[index];
                          return _TagTile(
                            tagName: tag.name,
                            count: lp.series.where((s) => s.tagNames.contains(tag.name)).length,
                            color: _parseColor(tag.color),
                            onDelete: () => _confirmDelete(context, lp, tp, tag.name),
                            onTap: () {
                              lp.clearFilters();
                              lp.toggleTagFilter(tag.name);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Filtering by ${tag.name}'), duration: const Duration(seconds: 1))
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
          if (lp.isProcessing) _buildProgressOverlay(lp),
        ],
      ),
    );
  }

  Widget _buildProgressOverlay(LibraryProvider lp) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF6C3CE0).withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF6C3CE0)),
              const SizedBox(height: 20),
              Text(lp.processMessage, 
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: lp.processProgress,
                backgroundColor: Colors.white10,
                color: const Color(0xFF6C3CE0),
              ),
              const SizedBox(height: 8),
              Text('${(lp.processProgress * 100).toInt()}%', 
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTagDialog(BuildContext context, TagProvider tp) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('New Category Tag', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'e.g. [ROMANCE]', hintStyle: TextStyle(color: Colors.white24)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.isNotEmpty) {
                await tp.createTag(ctrl.text.trim().toUpperCase(), '#808080', '');
                if (ctx.mounted) Navigator.pop(ctx);
              }
            }, 
            child: const Text('Create')),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, LibraryProvider lp, TagProvider tp, String tagName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text('Delete Tag: $tagName'),
        content: const Text('This will remove the tag from all files and rename them physically. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await lp.deleteTagGlobally(tagName);
              await tp.loadTags();
            }, 
            child: const Text('Delete & Rename Files', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_off_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text('No tags found', 
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 18)),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF6C3CE0);
    }
  }
}

class _TagTile extends StatelessWidget {
  final String tagName;
  final int count;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TagTile({
    required this.tagName,
    required this.count,
    required this.color,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.label_rounded, color: color, size: 20),
        ),
        title: Text(tagName, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text('$count Series', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white24, size: 20),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
