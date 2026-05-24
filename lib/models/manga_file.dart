class MangaFile {
  final int? id;
  final String path;
  final String filename;
  final String title;
  final String? chapter;
  final String ext;
  final int size;
  final DateTime modifiedAt;
  final DateTime indexedAt;
  final List<String> tagNames;
  final bool isRemote;
  final int? remoteSourceId;

  MangaFile({
    this.id,
    required this.path,
    required this.filename,
    required this.title,
    this.chapter,
    required this.ext,
    required this.size,
    required this.modifiedAt,
    required this.indexedAt,
    this.tagNames = const [],
    this.isRemote = false,
    this.remoteSourceId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'filename': filename,
      'title': title,
      'chapter': chapter,
      'ext': ext,
      'size': size,
      'modified_at': modifiedAt.millisecondsSinceEpoch,
      'indexed_at': indexedAt.millisecondsSinceEpoch,
      'is_remote': isRemote ? 1 : 0,
      'remote_source_id': remoteSourceId,
    };
  }

  factory MangaFile.fromMap(Map<String, dynamic> map, {List<String>? tags}) {
    return MangaFile(
      id: map['id'] as int?,
      path: map['path'] as String,
      filename: map['filename'] as String,
      title: map['title'] as String,
      chapter: map['chapter'] as String?,
      ext: map['ext'] as String,
      size: map['size'] as int,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(map['modified_at'] as int),
      indexedAt: DateTime.fromMillisecondsSinceEpoch(map['indexed_at'] as int),
      tagNames: tags ?? [],
      isRemote: (map['is_remote'] as int? ?? 0) == 1,
      remoteSourceId: map['remote_source_id'] as int?,
    );
  }

  MangaFile copyWith({
    int? id,
    String? path,
    String? filename,
    String? title,
    String? chapter,
    String? ext,
    int? size,
    DateTime? modifiedAt,
    DateTime? indexedAt,
    List<String>? tagNames,
  }) {
    return MangaFile(
      id: id ?? this.id,
      path: path ?? this.path,
      filename: filename ?? this.filename,
      title: title ?? this.title,
      chapter: chapter ?? this.chapter,
      ext: ext ?? this.ext,
      size: size ?? this.size,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      indexedAt: indexedAt ?? this.indexedAt,
      tagNames: tagNames ?? this.tagNames,
      isRemote: isRemote ?? this.isRemote,
      remoteSourceId: remoteSourceId ?? this.remoteSourceId,
    );
  }

  @override
  String toString() => 'MangaFile(id: $id, title: $title, chapter: $chapter)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MangaFile && runtimeType == other.runtimeType && path == other.path;

  @override
  int get hashCode => path.hashCode;
}

/// Represents a grouped series of manga files sharing the same title.
class MangaSeries {
  final String title;
  final List<MangaFile> chapters;
  final List<String> tagNames;

  MangaSeries({
    required this.title,
    required this.chapters,
    required this.tagNames,
  });

  MangaFile get firstChapter {
    if (chapters.length == 1) return chapters.first;
    final sorted = List<MangaFile>.from(chapters)
      ..sort((a, b) => (a.chapter ?? '').compareTo(b.chapter ?? ''));
    return sorted.first;
  }

  int get chapterCount => chapters.length;

  bool get isStandalone => chapters.length == 1 && chapters.first.chapter == null;
}
