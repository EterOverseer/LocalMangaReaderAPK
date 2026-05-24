import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tag.dart';
import '../providers/tag_provider.dart';

class TagManagerScreen extends StatefulWidget {
  const TagManagerScreen({super.key});
  @override
  State<TagManagerScreen> createState() => _TagManagerScreenState();
}

class _TagManagerScreenState extends State<TagManagerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TagProvider>().loadTags();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TagProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E), elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Tag Manager', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded, color: Color(0xFF6C3CE0)),
            onPressed: () => _showCreateDialog()),
        ],
      ),
      body: tp.tags.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.label_off_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 12),
            Text('No tags yet', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Tag'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C3CE0), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: tp.tags.length,
            itemBuilder: (ctx, i) => _TagTile(tag: tp.tags[i],
              onEdit: () => _showEditDialog(tp.tags[i]),
              onDelete: () => _confirmDelete(tp.tags[i])),
          ),
    );
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    Color pickedColor = const Color(0xFF6C3CE0);
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Tag', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDeco('Tag Name (e.g. R17)')),
          const SizedBox(height: 10),
          TextField(controller: labelCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDeco('Label (e.g. Ages 17+)')),
          const SizedBox(height: 12),
          const Align(alignment: Alignment.centerLeft,
            child: Text('Color', style: TextStyle(color: Colors.white54, fontSize: 12))),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: _presetColors.map((c) =>
            GestureDetector(
              onTap: () => setS(() => pickedColor = c),
              child: Container(width: 32, height: 32,
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8),
                  border: pickedColor == c ? Border.all(color: Colors.white, width: 2) : null)),
            )).toList()),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim().toUpperCase();
              if (name.isEmpty) return;
              final hex = '#${pickedColor.value.toRadixString(16).substring(2).toUpperCase()}';
              await context.read<TagProvider>().createTag(name, hex, labelCtrl.text.trim());
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C3CE0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Create', style: TextStyle(color: Colors.white))),
        ],
      ),
    ));
  }

  void _showEditDialog(Tag tag) {
    final labelCtrl = TextEditingController(text: tag.label);
    final nameCtrl = TextEditingController(text: tag.name);
    Color pickedColor = tag.colorValue;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Tag', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDeco('Tag Name')),
          const SizedBox(height: 10),
          TextField(controller: labelCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDeco('Label')),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: _presetColors.map((c) =>
            GestureDetector(
              onTap: () => setS(() => pickedColor = c),
              child: Container(width: 32, height: 32,
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8),
                  border: pickedColor == c ? Border.all(color: Colors.white, width: 2) : null)),
            )).toList()),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim().toUpperCase();
              final hex = '#${pickedColor.value.toRadixString(16).substring(2).toUpperCase()}';
              final tp = context.read<TagProvider>();
              await tp.updateTag(tag.id!, color: hex, label: labelCtrl.text.trim());
              if (newName != tag.name && newName.isNotEmpty) {
                await tp.renameTag(tag.id!, tag.name, newName);
              }
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C3CE0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Save', style: TextStyle(color: Colors.white))),
        ],
      ),
    ));
  }

  void _confirmDelete(Tag tag) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delete Tag', style: TextStyle(color: Colors.white)),
      content: Text('Delete tag [${tag.name}]? This will remove it from all filenames.',
        style: TextStyle(color: Colors.white.withOpacity(0.7))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          onPressed: () async {
            await context.read<TagProvider>().deleteTag(tag.id!, tag.name);
            if (mounted) Navigator.pop(ctx);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Delete', style: TextStyle(color: Colors.white))),
      ],
    ));
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint, hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
    filled: true, fillColor: const Color(0xFF2A2A3E),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none));

  static const _presetColors = [
    Color(0xFFFF5733), Color(0xFFC70039), Color(0xFF900C3F), Color(0xFF581845),
    Color(0xFF6C3CE0), Color(0xFF3498DB), Color(0xFF1ABC9C), Color(0xFF27AE60),
    Color(0xFFF39C12), Color(0xFFE74C3C), Color(0xFF9B59B6), Color(0xFF2ECC71),
    Color(0xFFE67E22), Color(0xFF1F618D), Color(0xFFD4AC0D), Color(0xFF7D3C98),
  ];
}

class _TagTile extends StatelessWidget {
  final Tag tag;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TagTile({required this.tag, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onEdit,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(width: 40, height: 40,
          decoration: BoxDecoration(color: tag.colorValue, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(tag.name.substring(0, tag.name.length > 2 ? 2 : tag.name.length),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))),
        title: Text('[${tag.name}]', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: tag.label.isNotEmpty
          ? Text(tag.label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12))
          : null,
        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
          onPressed: onDelete),
      ),
    );
  }
}
