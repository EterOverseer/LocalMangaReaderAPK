# MangaReader: Minimal & Modern Development Guide

## Project Overview
**MangaReader** is a Flutter-based application designed for a professional and minimal manga reading experience. It supports local file scanning (Zip, CBZ, PDF), remote storage integration (WebDAV, SMB), and advanced archive management like merging.

## Tech Stack
- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Database**: SQLite (`sqflite`)
- **Key Packages**:
  - `pdfx`: PDF rendering
  - `archive`: Zip/CBZ handling
  - `palette_generator`: Dynamic UI coloring
  - `animations`: Smooth screen transitions
  - `google_fonts`: Modern typography (Inter)

## Architectural Overview
The project follows a modular architecture:
- **Models**: Defines data structures (MangaFile, MangaSeries, Tag, etc.)
- **Providers**: Contains business logic and state (LibraryProvider, ReaderProvider, TagProvider)
- **Repositories**: Handles database and persistence layers
- **Services**: Manages specialized tasks (ScannerService, MergeService, ArchiveService)
- **Screens**: UI layer for library, reader, and management tools

## Core Features
1. **Reactive Tag System**: Tags update across the UI immediately without manual refresh.
2. **Merge Tool**: Select multiple manga, reorder them via drag-and-drop, and combine them into a single archive.
3. **Immersive Reader**: Minimalist UI with gesture-based navigation and background pre-fetching for gapless reading.
4. **Optimized Transitions**: Deferring heavy loads during animations to ensure 60fps UI performance.

## Build Instructions
1. Ensure Flutter SDK is installed and configured.
2. Run `flutter pub get` to fetch dependencies.
3. To build for release:
   ```bash
   flutter build apk --release
   ```
4. The APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

---
*Created by Gemini CLI Agent for EterOverseer*
