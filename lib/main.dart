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

  // Load Settings before App starts to prevent flicker
  final settingsProvider = SettingsProvider(dbHelper);
  await settingsProvider.loadSettings();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
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
    final settings = context.watch<SettingsProvider>();

    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C3CE0),
      brightness: Brightness.dark,
      surface: const Color(0xFF0F0F1A),
      onSurface: Colors.white,
      primary: const Color(0xFF6C3CE0),
      secondary: const Color(0xFFBB86FC),
    );

    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
      surface: Colors.white,
      onSurface: Colors.blue[900]!,
      primary: Colors.blue,
      secondary: Colors.blueAccent,
    );

    return MaterialApp(
      title: 'EterOverseer: Manga Reader',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: lightColorScheme,
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
          bodyColor: Colors.blue[800],
          displayColor: Colors.blue[900],
        ).copyWith(
          titleLarge: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.blue[900]),
          titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.blue[800]),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.blue.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.blue.withOpacity(0.05))),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: Colors.blue),
          titleTextStyle: GoogleFonts.inter(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      // Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: darkColorScheme,
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
          titleLarge: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
          titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white70),
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
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: const MainScreen(),
    );
  }
}
