import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'database/database_helper.dart';
import 'repositories/manga_repository.dart';
import 'repositories/tag_repository.dart';
import 'repositories/progress_repository.dart';
import 'repositories/remote_source_repository.dart';
import 'services/scanner_service.dart';
import 'services/archive_service.dart';
import 'services/backup_service.dart';
import 'services/remote_storage_service.dart';
import 'services/merge_service.dart';
import 'providers/library_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/tag_provider.dart';
import 'providers/reader_provider.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Database
  final dbHelper = DatabaseHelper();

  // Initialize Repositories
  final mangaRepo = MangaRepository(dbHelper);
  final tagRepo = TagRepository(dbHelper);
  final progressRepo = ProgressRepository(dbHelper);
  final remoteRepo = RemoteSourceRepository(dbHelper);

  // Initialize Services
  final archiveService = ArchiveService();
  final remoteService = RemoteStorageService();
  final mergeService = MergeService(archiveService);
  final scannerService = ScannerService(dbHelper, mangaRepo, tagRepo, archiveService, remoteService);
  final backupService = BackupService(dbHelper, mangaRepo, tagRepo, progressRepo);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(dbHelper)),
        ChangeNotifierProvider(create: (_) => TagProvider(tagRepo, mangaRepo)),
        Provider.value(value: mergeService),
        ChangeNotifierProvider(
          create: (_) => LibraryProvider(
            dbHelper,
            mangaRepo,
            tagRepo,
            progressRepo,
            scannerService,
            archiveService,
            backupService,
            remoteRepo,
            mergeService,
          ),
        ),
        ChangeNotifierProvider(create: (_) => ReaderProvider(progressRepo, archiveService, remoteService, remoteRepo)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C3CE0),
      brightness: Brightness.dark,
      surface: const Color(0xFF0F0F1A),
      onSurface: Colors.white,
      primary: const Color(0xFF6C3CE0),
      secondary: const Color(0xFFBB86FC),
    );

    return MaterialApp(
      title: 'EterOverseer: Manga Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: darkColorScheme,
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
          titleLarge: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 24),
          titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1A2E),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const MainScreen(),
    );
  }
}
