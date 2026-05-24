import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Shared widget for rendering a single manga page from bytes.
class PageViewWidget extends StatelessWidget {
  final Future<Uint8List?> pageFuture;
  final Color backgroundColor;
  final BoxFit fit;

  const PageViewWidget({
    super.key,
    required this.pageFuture,
    this.backgroundColor = Colors.black,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: pageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: backgroundColor,
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6C3CE0),
                strokeWidth: 2,
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Container(
            color: backgroundColor,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load page',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          color: backgroundColor,
          child: Center(
            child: Image.memory(
              snapshot.data!,
              fit: fit,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Icon(
                Icons.broken_image_rounded,
                color: Colors.white.withOpacity(0.3),
                size: 48,
              ),
            ),
          ),
        );
      },
    );
  }
}
