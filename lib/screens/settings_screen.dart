import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/scanner_service.dart';
import '../services/archive_service.dart';
import '../utils/config_manager.dart';
import '../database/database_helper.dart';
import '../models/remote_source.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const _SectionHeader('Source Folders'),
        _SourceFoldersSection(),
        const SizedBox(height: 24),
        const _SectionHeader('Remote Sources (Beta)'),
        _RemoteSourcesSection(),
        const SizedBox(height: 24),
        const _SectionHeader('Display'),
        _SettingTile(
          icon: Icons.grid_view_rounded,
          title: 'Grid Columns',
          subtitle: '${sp.gridColumns} columns',
          trailing: ToggleButtons(
            isSelected: [sp.gridColumns == 2, sp.gridColumns == 3],
            onPressed: (i) => sp.setGridColumns(i + 2),
            borderRadius: BorderRadius.circular(8),
            selectedColor: Colors.white,
            fillColor: theme.primaryColor,
            color: colorScheme.onSurface.withOpacity(0.5),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
            children: const [Text(' 2 '), Text(' 3 ')],
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader('Reader'),
        _SettingTile(
          icon: Icons.auto_stories_rounded,
          title: 'Default Mode',
          subtitle: sp.defaultReaderMode == 'scroll'
              ? 'Vertical Scroll'
              : 'Horizontal Flip',
          trailing: ToggleButtons(
            isSelected: [
              sp.defaultReaderMode == 'scroll',
              sp.defaultReaderMode == 'flip'
            ],
            onPressed: (i) => sp.setDefaultReaderMode(i == 0 ? 'scroll' : 'flip'),
            borderRadius: BorderRadius.circular(8),
            selectedColor: Colors.white,
            fillColor: theme.primaryColor,
            color: colorScheme.onSurface.withOpacity(0.5),
            constraints: const BoxConstraints(minWidth: 52, minHeight: 36),
            children: const [
              Icon(Icons.swap_vert, size: 18),
              Icon(Icons.swap_horiz, size: 18),
            ],
          ),
        ),
        _SettingTile(
          icon: Icons.format_textdirection_r_to_l,
          title: 'RTL Mode',
          subtitle: sp.rtlMode ? 'Right to left' : 'Left to right',
          trailing: Switch(
              value: sp.rtlMode,
              onChanged: sp.setRtlMode,
              activeColor: theme.primaryColor),
        ),
        _SettingTile(
          icon: Icons.sync_rounded,
          title: 'Auto-scan on Start',
          subtitle: 'Check for new files when app opens',
          trailing: Switch(
              value: sp.autoScan,
              onChanged: sp.setAutoScan,
              activeColor: theme.primaryColor),
        ),
        _SettingTile(
          icon: Icons.palette_rounded,
          title: 'Reader Background',
          subtitle:
              sp.readerBg.substring(0, 1).toUpperCase() + sp.readerBg.substring(1),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            _BgBtn(
                label: 'B',
                color: Colors.black,
                active: sp.readerBg == 'black',
                onTap: () => sp.setReaderBg('black')),
            const SizedBox(width: 6),
            _BgBtn(
                label: 'W',
                color: Colors.white,
                active: sp.readerBg == 'white',
                onTap: () => sp.setReaderBg('white')),
            const SizedBox(width: 6),
            _BgBtn(
                label: 'S',
                color: const Color(0xFFF5E6C8),
                active: sp.readerBg == 'sepia',
                onTap: () => sp.setReaderBg('sepia')),
          ]),
        ),
        const SizedBox(height: 20),
        const _SectionHeader('Data'),
        _ActionTile(
          icon: Icons.refresh_rounded,
          title: 'Re-scan Library',
          subtitle: 'Full rescan of all source folders',
          color: theme.primaryColor,
          onTap: () async {
            final lp = context.read<LibraryProvider>();
            final result = await lp.scan();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Scan complete: ${result.added} added, ${result.updated} updated, ${result.removed} removed'),
                  backgroundColor: theme.primaryColor));
            }
          },
        ),
        const SizedBox(height: 20),
        const _SectionHeader('Backup & Migration'),
        _ActionTile(
          icon: Icons.backup_rounded,
          title: 'Create Backup',
          subtitle: 'Save progress and tags to Download folder',
          color: Colors.teal,
          onTap: () async {
            try {
              final path = await context.read<LibraryProvider>().createBackup();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Backup saved to $path'),
                    backgroundColor: theme.primaryColor));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Backup failed: $e'),
                    backgroundColor: Colors.redAccent));
              }
            }
          },
        ),
        _ActionTile(
          icon: Icons.restore_rounded,
          title: 'Restore Backup',
          subtitle: 'Load progress and tags from JSON file',
          color: Colors.blueAccent,
          onTap: () async {
            try {
              final result = await FilePicker.platform
                  .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
              if (result == null || result.files.isEmpty) return;
              final path = result.files.single.path;
              if (path == null) return;

              if (context.mounted) {
                await context.read<LibraryProvider>().restoreBackup(path);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Backup restored successfully'),
                    backgroundColor: theme.primaryColor));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Restore failed: $e'),
                    backgroundColor: Colors.redAccent));
              }
            }
          },
        ),
        const SizedBox(height: 20),
        const _SectionHeader('About'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Manga Reader',
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 4),
            Text('Version 1.1.0 (Remote Support)',
                style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.4), fontSize: 12)),
            const SizedBox(height: 8),
            Text('Local & Remote manga reader for Android.\nSupports ZIP, CBZ, and PDF files.',
                style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.5), fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)));
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  const _SettingTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.trailing});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.onSurface.withOpacity(0.38), size: 22),
        title:
            Text(title, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14)),
        subtitle: Text(subtitle,
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.3), fontSize: 11)),
        trailing: trailing,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color, size: 22),
        title:
            Text(title, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14)),
        subtitle: Text(subtitle,
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.3), fontSize: 11)),
        trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withOpacity(0.24)),
      ),
    );
  }
}

class _BgBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _BgBtn(
      {required this.label,
      required this.color,
      required this.active,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
        onTap: onTap,
        child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: active ? theme.primaryColor : theme.colorScheme.onSurface.withOpacity(0.12),
                    width: active ? 2 : 1)),
            child: Center(
                child: Text(label,
                    style: TextStyle(
                        color: color == Colors.white ? Colors.black : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)))));
  }
}

class _SourceFoldersSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LibraryProvider>();
    final theme = Theme.of(context);
    return FutureBuilder<List<String>>(
      future: lp.getSourceFolders(),
      builder: (ctx, snap) {
        final folders = snap.data ?? [];
        return Container(
          decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            if (folders.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No source folders configured',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.3), fontSize: 13)))
            else
              ...folders.map((f) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.folder, color: Colors.amber, size: 20),
                    title: Text(f,
                        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12)),
                    trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.redAccent, size: 18),
                        onPressed: () => lp.removeSourceFolder(f)),
                  )),
            Divider(color: theme.dividerColor.withOpacity(0.05), height: 1),
            ListTile(
                dense: true,
                leading:
                    Icon(Icons.add_rounded, color: theme.primaryColor, size: 20),
                title: Text('Add folder',
                    style: TextStyle(color: theme.primaryColor, fontSize: 13)),
                onTap: () => _addFolder(context)),
          ]),
        );
      },
    );
  }

  void _addFolder(BuildContext context) {
    final theme = Theme.of(context);
    final ctrl = TextEditingController(text: '/storage/emulated/0/');
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: theme.cardColor,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Source'),
              content: TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                      hintText: '/storage/emulated/0/Manga',
                      hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.3)),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.folder_open, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                        onPressed: () async {
                          String? path = await FilePicker.platform.getDirectoryPath();
                          if (path != null) ctrl.text = path;
                        },
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child:
                        Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)))),
                ElevatedButton(
                    onPressed: () async {
                      final p = ctrl.text.trim();
                      if (p.isNotEmpty) {
                        await context.read<LibraryProvider>().addSourceFolder(p);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: const Text('Add')),
              ],
            ));
  }
}

class _RemoteSourcesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LibraryProvider>();
    final sources = lp.remoteSources;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
          color: theme.cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        if (sources.isEmpty)
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No remote sources configured',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.3), fontSize: 13)))
        else
          ...sources.map((s) => ListTile(
                dense: true,
                leading: Icon(
                    s.type == RemoteSourceType.smb
                        ? Icons.lan_rounded
                        : Icons.cloud_rounded,
                    color: Colors.lightBlueAccent,
                    size: 20),
                title: Text(s.name,
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13)),
                subtitle: Text(s.url,
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.3), fontSize: 10)),
                trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.redAccent, size: 18),
                    onPressed: () => lp.removeRemoteSource(s.id!)),
              )),
        Divider(color: theme.dividerColor.withOpacity(0.05), height: 1),
        ListTile(
            dense: true,
            leading: Icon(Icons.add_rounded, color: theme.primaryColor, size: 20),
            title: Text('Add Remote Source',
                style: TextStyle(color: theme.primaryColor, fontSize: 13)),
            onTap: () => _addRemoteSource(context)),
      ]),
    );
  }

  void _addRemoteSource(BuildContext context) {
    final theme = Theme.of(context);
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: 'http://');
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final pathCtrl = TextEditingController(text: '/');
    RemoteSourceType type = RemoteSourceType.webdav;

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setS) => AlertDialog(
                  backgroundColor: theme.cardColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Add Remote Source'),
                  content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButton<RemoteSourceType>(
                        value: type,
                        dropdownColor: theme.cardColor,
                        isExpanded: true,
                        underline: const SizedBox(),
                        onChanged: (v) => setS(() {
                          type = v!;
                          if (type == RemoteSourceType.smb && urlCtrl.text.startsWith('http')) {
                            urlCtrl.text = '192.168.1.100';
                          }
                        }),
                        items: const [
                          DropdownMenuItem(
                              value: RemoteSourceType.webdav, child: Text('WebDAV (Nextcloud)')),
                          DropdownMenuItem(
                              value: RemoteSourceType.smb, child: Text('SMB (Windows/NAS)')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _input(context, nameCtrl, 'Name (e.g. My Nextcloud)'),
                      const SizedBox(height: 8),
                      _input(context, urlCtrl, type == RemoteSourceType.webdav ? 'URL (http://...)' : 'Host IP'),
                      const SizedBox(height: 8),
                      _input(context, userCtrl, 'Username'),
                      const SizedBox(height: 8),
                      _input(context, passCtrl, 'Password', obscure: true),
                      const SizedBox(height: 8),
                      _input(context, pathCtrl, 'Root Path (e.g. /Manga)'),
                    ]),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Cancel',
                            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)))),
                    ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.isEmpty || urlCtrl.text.isEmpty) return;
                          final source = RemoteSource(
                            type: type,
                            name: nameCtrl.text.trim(),
                            url: urlCtrl.text.trim(),
                            username: userCtrl.text.trim(),
                            password: passCtrl.text.trim(),
                            rootPath: pathCtrl.text.trim(),
                          );
                          await context.read<LibraryProvider>().addRemoteSource(source);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white),
                        child: const Text('Add')),
                  ],
                )));
  }

  Widget _input(BuildContext context, TextEditingController ctrl, String hint, {bool obscure = false}) {
    final theme = Theme.of(context);
    return TextField(
        controller: ctrl,
        obscureText: obscure,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.3), fontSize: 13),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            isDense: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)));
  }
}
