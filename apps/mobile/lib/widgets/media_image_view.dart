import 'dart:convert';
import 'package:flutter/cupertino.dart';

class MediaImageView extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const MediaImageView({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty || url.contains('default_avatar') || url.endsWith('.svg')) {
      final size = width ?? height ?? 40.0;
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(size / 2),
        ),
        child: Center(
          child: Icon(
            CupertinoIcons.person_fill,
            color: const Color(0xFF8E8E93),
            size: size * 0.55,
          ),
        ),
      );
    }

    if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        if (commaIdx != -1) {
          final bytes = base64Decode(url.substring(commaIdx + 1));
          return Image.memory(
            bytes,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, __, ___) =>
                errorWidget ?? const Icon(CupertinoIcons.photo, color: CupertinoColors.systemGrey),
          );
        }
      } catch (_) {}
    }

    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) =>
          errorWidget ?? const Icon(CupertinoIcons.photo, color: CupertinoColors.systemGrey),
    );
  }
}

