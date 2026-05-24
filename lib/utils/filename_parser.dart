/// Parses and composes manga filenames following the convention:
///   [TAG1][TAG2]Title_Chapter.ext
///
/// Examples:
///   [R17][X1]Samikato_Chap.1.zip → tags: [R17, X1], title: Samikato, chapter: Chap.1
///   [CUTE]Nekochan.pdf → tags: [CUTE], title: Nekochan, chapter: null
class FilenameParser {
  /// Regex to match [UPPERCASE] tags at start of filename.
  static final RegExp _tagPattern = RegExp(r'\[([a-zA-Z0-9\s]+)\]');

  /// Parse a filename into its components.
  static ParsedFilename parse(String filename) {
    // Remove extension
    final lastDot = filename.lastIndexOf('.');
    String ext = '';
    String nameWithoutExt = filename;
    if (lastDot > 0) {
      ext = filename.substring(lastDot + 1).toLowerCase();
      nameWithoutExt = filename.substring(0, lastDot);
    }

    // Extract tags from anywhere in the filename
    final tags = <String>[];
    final allMatches = _tagPattern.allMatches(nameWithoutExt);
    String remaining = nameWithoutExt;
    
    for (final match in allMatches) {
      tags.add(match.group(1)!);
      // Remove the full tag including brackets from the title
      remaining = remaining.replaceFirst(match.group(0)!, '');
    }
    remaining = remaining.trim();

    // Split into title and chapter
    String title;
    String? chapter;
    final underscoreIndex = remaining.indexOf('_');
    if (underscoreIndex >= 0) {
      title = remaining.substring(0, underscoreIndex).trim();
      chapter = remaining.substring(underscoreIndex + 1).trim();
      if (chapter.isEmpty) chapter = null;
    } else {
      title = remaining.trim();
      chapter = null;
    }

    return ParsedFilename(
      tags: tags,
      title: title,
      chapter: chapter,
      ext: ext,
      originalFilename: filename,
    );
  }

  /// Compose a filename from components.
  static String compose({
    required List<String> tags,
    required String title,
    String? chapter,
    required String ext,
  }) {
    final buffer = StringBuffer();
    for (final tag in tags) {
      buffer.write('[${tag.toUpperCase()}]');
    }
    buffer.write(title);
    if (chapter != null && chapter.isNotEmpty) {
      buffer.write('_$chapter');
    }
    buffer.write('.$ext');
    return buffer.toString();
  }

  /// Add a tag to a filename, returning the new filename.
  static String addTag(String filename, String tagName) {
    final parsed = parse(filename);
    final upperTag = tagName.toUpperCase();
    if (parsed.tags.contains(upperTag)) return filename;
    
    final newTags = [upperTag, ...parsed.tags];
    return compose(
      tags: newTags,
      title: parsed.title,
      chapter: parsed.chapter,
      ext: parsed.ext,
    );
  }

  /// Remove a tag from a filename, returning the new filename.
  static String removeTag(String filename, String tagName) {
    final t = RegExp.escape(tagName.toUpperCase());
    // Regex to find [TAG] or [ tag ] case-insensitively
    final regex = RegExp('\\[\\s*$t\\s*\\]', caseSensitive: false);
    String result = filename.replaceAll(regex, '');
    return _cleanupFilename(result);
  }

  /// Rename a tag in a filename, returning the new filename.
  static String renameTag(String filename, String oldTag, String newTag) {
    final ot = RegExp.escape(oldTag.toUpperCase());
    final nt = newTag.toUpperCase();
    final regex = RegExp('\\[\\s*$ot\\s*\\]', caseSensitive: false);
    String result = filename.replaceAll(regex, '[$nt]');
    return _cleanupFilename(result);
  }

  static String _cleanupFilename(String filename) {
    return filename
        .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces to single space
        .replaceAll(RegExp(r'\s+\.'), '.') // Space before extension
        .trim();
  }
}

class ParsedFilename {
  final List<String> tags;
  final String title;
  final String? chapter;
  final String ext;
  final String originalFilename;

  ParsedFilename({
    required this.tags,
    required this.title,
    this.chapter,
    required this.ext,
    required this.originalFilename,
  });

  @override
  String toString() =>
      'ParsedFilename(tags: $tags, title: $title, chapter: $chapter, ext: $ext)';
}
