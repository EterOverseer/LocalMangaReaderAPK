import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/library_provider.dart';
import '../../models/remote_source.dart';

class DirMgrTab extends StatelessWidget {
  const DirMgrTab({super.key});

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LibraryProvider>();
    final sources = lp.sourceFolders;
    final remoteSources = lp.remoteSources;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Source Manager', 
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF6C3CE0)),
            onPressed: () => _addLocalSource(context, lp),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_circle_rounded, color: Color(0xFF6C3CE0)),
            onPressed: () => _addRemoteSource(context, lp),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Local Sources'),
          ...sources.map((s) => _SourceCard(
            name: s,
            isRemote: false,
            onDelete: () => lp.removeSourceFolder(s),
          )),
          const SizedBox(height: 24),
          _sectionHeader('Remote Sources'),
          ...remoteSources.map((s) => _SourceCard(
            name: s.name,
            isRemote: true,
            source: s,
            onDelete: () => lp.removeRemoteSource(s.id!),
          )),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Text(title, 
        style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  void _addLocalSource(BuildContext context, LibraryProvider lp) async {
    // We already have a mechanism for this in LibraryScreen, but we can call it here
  }

  void _addRemoteSource(BuildContext context, LibraryProvider lp) {
    // Show dialog for remote source
  }
}

class _SourceCard extends StatelessWidget {
  final String name;
  final bool isRemote;
  final RemoteSource? source;
  final VoidCallback onDelete;

  const _SourceCard({
    required this.name,
    required this.isRemote,
    this.source,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(
            isRemote ? Icons.cloud_queue_rounded : Icons.folder_open_rounded,
            color: const Color(0xFF6C3CE0),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                if (isRemote)
                  Text(source?.url ?? '', 
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          if (isRemote) ...[
            // Advanced Buttons for Remote
            _ActionButton(icon: Icons.sync_problem_rounded, tooltip: 'Test Connection', onTap: () {}),
            _ActionButton(icon: Icons.file_download_outlined, tooltip: 'Download to Local', onTap: () {}),
            _ActionButton(icon: Icons.settings_input_component_rounded, tooltip: 'Path Settings', onTap: () {}),
          ],
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        icon: Icon(icon, color: Colors.white70, size: 20),
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    );
  }
}
