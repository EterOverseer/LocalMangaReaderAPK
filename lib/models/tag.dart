import 'package:flutter/material.dart';

class Tag {
  final int? id;
  final String name;
  final String color;
  final String label;
  final DateTime createdAt;

  Tag({
    this.id,
    required this.name,
    required this.color,
    required this.label,
    required this.createdAt,
  });

  Color get colorValue {
    try {
      String hex = color.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'label': label,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as String,
      label: map['label'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'color': color,
      'label': label,
    };
  }

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      name: json['name'] as String,
      color: json['color'] as String? ?? '#808080',
      label: json['label'] as String? ?? '',
      createdAt: DateTime.now(),
    );
  }

  Tag copyWith({
    int? id,
    String? name,
    String? color,
    String? label,
    DateTime? createdAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Tag(name: $name, color: $color)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}
