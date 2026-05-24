import 'package:flutter/material.dart';
import '../models/tag.dart';

class TagChip extends StatelessWidget {
  final String tagName;
  final Tag? tagData;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final double fontSize;

  const TagChip({
    super.key,
    required this.tagName,
    this.tagData,
    this.selected = false,
    this.onTap,
    this.onDelete,
    this.fontSize = 10,
  });

  Color get _color {
    if (tagData != null) return tagData!.colorValue;
    return _defaultColor(tagName);
  }

  static Color _defaultColor(String name) {
    final hash = name.hashCode;
    return HSLColor.fromAHSL(1.0, (hash % 360).toDouble(), 0.65, 0.55).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final isDark = color.computeLuminance() < 0.5;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (onDelete != null) {
      return Chip(
        label: Text(
          tagName,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: color.withOpacity(selected ? 1.0 : 0.85),
        deleteIcon: Icon(Icons.close, size: 14, color: textColor.withOpacity(0.7)),
        onDeleted: onDelete,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: selected
              ? BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5)
              : BorderSide.none,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(selected ? 1.0 : 0.85),
          borderRadius: BorderRadius.circular(6),
          border: selected
              ? Border.all(color: Colors.white.withOpacity(0.5), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          tagName,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
