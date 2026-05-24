# AI Context: MangaReader (EterOverseer Renovated)

## Context for LLMs
This project is a high-performance Flutter Manga Reader. It uses a Repository-Service-Provider pattern for modularity.

### Critical Components Mapping:
- **`lib/providers/library_provider.dart`**: Central state for the library. Handles filtering, sorting, and coordinates scanning/merging.
- **`lib/providers/reader_provider.dart`**: State for the reading session. Manages page caching and immersive UI toggles.
- **`lib/services/merge_service.dart`**: Backend logic for combining multiple Zip/PDF files into a single CBZ.
- **`lib/services/scanner_service.dart`**: Handles filesystem scanning for local and remote (WebDAV/SMB) sources.
- **`lib/services/archive_service.dart`**: Low-level extraction logic for images from Zip and PDF.
- **`lib/utils/filename_parser.dart`**: Critical regex-based logic for the `[TAG]Title_Chapter.ext` convention.

### Logic Rules:
- **Naming Convention**: Always follow `[TAG1][TAG2]Title_Chapter.ext`.
- **Tag Casing**: Tags are stored and filtered in a Case-Insensitive manner in logic but preferred Uppercase in storage.
- **Reader Loading**: Heavy IO in `ReaderScreen` must be deferred until transition animations finish to prevent lag.

### Environment:
- SDK: `^3.11.5`
- Main Entry: `lib/main.dart`
