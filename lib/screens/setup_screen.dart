import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/library_provider.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _pathCtrl = TextEditingController(text: '/storage/emulated/0/');
  bool _isProcessing = false;

  Future<void> _selectFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() => _pathCtrl.text = selectedDirectory);
    }
  }

  Future<void> _importBackup() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'db'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isProcessing = true);
      try {
        await context.read<LibraryProvider>().restoreBackup(result.files.single.path!);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.redAccent),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _confirmPath() async {
    final path = _pathCtrl.text.trim();
    if (path.isEmpty) return;

    setState(() => _isProcessing = true);
    final dir = Directory(path);
    if (await dir.exists()) {
      await context.read<LibraryProvider>().addSourceFolder(path);
      await context.read<LibraryProvider>().scan();
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Directory does not exist'), backgroundColor: Colors.redAccent),
        );
      }
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.menu_book_rounded, size: 80, color: Color(0xFF6C3CE0)),
              const SizedBox(height: 24),
              const Text(
                'Welcome to MangaReader',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Let\'s set up your library to get started',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 48),
              
              // Path Input
              TextField(
                controller: _pathCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Manga Folder Path',
                  labelStyle: const TextStyle(color: Color(0xFF6C3CE0)),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.folder_open, color: Colors.white70),
                    onPressed: _selectFolder,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _confirmPath,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C3CE0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isProcessing 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Start Scanning', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
              
              const SizedBox(height: 32),
              const Row(children: [
                Expanded(child: Divider(color: Colors.white24)),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('OR', style: TextStyle(color: Colors.white24))),
                Expanded(child: Divider(color: Colors.white24)),
              ]),
              const SizedBox(height: 32),
              
              // Import Choice
              OutlinedButton.icon(
                onPressed: _isProcessing ? null : _importBackup,
                icon: const Icon(Icons.import_export_rounded),
                label: const Text('Import Backup File'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
