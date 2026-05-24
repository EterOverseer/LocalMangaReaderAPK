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
    final theme = Theme.of(context);
    
    final filteredTags = tp.tags.where((t) => 
      t.name.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Categories', 
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.onSurface.withOpacity(0.54)),
            onPressed: () async {
              await tp.loadTags();
              await lp.initialize();
            },
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: theme.primaryColor),
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
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search tags...',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.24)),
                    prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurface.withOpacity(0.24), size: 20),
                    filled: true,
                    fillColor: theme.cardColor,
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
                            color: _parseColor(tag.color, theme.primaryColor),
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
          if (lp.isProcessing) _buildProgressOverlay(context, lp),
        ],
      ),
    );
  }

  Widget _buildProgressOverlay(BuildContext context, LibraryProvider lp) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.primaryColor.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.primaryColor),
              const SizedBox(height: 20),
              Text(lp.processMessage, 
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: lp.processProgress,
                backgroundColor: theme.colorScheme.onSurface.withOpacity(0.1),
                color: theme.primaryColor,
              ),
              const SizedBox(height: 8),
              Text('${(lp.processProgress * 100).toInt()}%', 
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.54))),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTagDialog(BuildContext context, TagProvider tp) {
    final theme = Theme.of(context);
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: const Text('New Category Tag'),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'e.g. [ROMANCE]', 
            hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.24))
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)))),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.isNotEmpty) {
                await tp.createTag(ctrl.text.trim().toUpperCase(), '#808080', '');
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create')),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, LibraryProvider lp, TagProvider tp, String tagName) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Delete Tag: $tagName'),
        content: const Text('This will remove the tag from all files and rename them physically. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await lp.deleteTagGlobally(tagName);
              await tp.loadTags();
            }, 
            child: const Text('Delete & Rename Files')),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_off_rounded, size: 80, color: theme.colorScheme.onSurface.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text('No tags found', 
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 18)),
        ],
      ),
    );
  }

  Color _parseColor(String hex, Color fallback) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return fallback;
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
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
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
        title: Text(tagName, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text('$count Series', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.38))),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.onSurface.withOpacity(0.24), size: 20),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
