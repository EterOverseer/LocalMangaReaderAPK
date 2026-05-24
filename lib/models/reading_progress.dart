class ReadingProgress {
  final int? id;
  final int mangaId;
  final int page;
  final int totalPages;
  final DateTime lastReadAt;

  ReadingProgress({
    this.id,
    required this.mangaId,
    required this.page,
    required this.totalPages,
    required this.lastReadAt,
  });

  double get progressPercent =>
      totalPages > 0 ? (page + 1) / totalPages : 0.0;

  bool get isRead => totalPages > 0 && page >= totalPages - 1;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'manga_id': mangaId,
      'page': page,
      'total_pages': totalPages,
      'last_read_at': lastReadAt.millisecondsSinceEpoch,
    };
  }

  factory ReadingProgress.fromMap(Map<String, dynamic> map) {
    return ReadingProgress(
      id: map['id'] as int?,
      mangaId: map['manga_id'] as int,
      page: map['page'] as int,
      totalPages: map['total_pages'] as int,
      lastReadAt: DateTime.fromMillisecondsSinceEpoch(map['last_read_at'] as int),
    );
  }

  ReadingProgress copyWith({
    int? id,
    int? mangaId,
    int? page,
    int? totalPages,
    DateTime? lastReadAt,
  }) {
    return ReadingProgress(
      id: id ?? this.id,
      mangaId: mangaId ?? this.mangaId,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }
}
