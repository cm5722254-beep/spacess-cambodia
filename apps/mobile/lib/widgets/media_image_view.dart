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

  Widget _buildDefaultAvatar(BuildContext context) {
    final size = width ?? height ?? 40.0;
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB);
    final iconColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Icon(
          CupertinoIcons.person_fill,
          color: iconColor,
          size: size * 0.58,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty || cleanUrl.contains('default_avatar') || cleanUrl.endsWith('.svg')) {
      return _buildDefaultAvatar(context);
    }

    if (cleanUrl.startsWith('data:image')) {
      try {
        final commaIdx = cleanUrl.indexOf(',');
        if (commaIdx != -1) {
          final bytes = base64Decode(cleanUrl.substring(commaIdx + 1));
          return Image.memory(
            bytes,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, __, ___) => errorWidget ?? _buildDefaultAvatar(context),
          );
        }
      } catch (_) {}
    }

    return Image.network(
      cleanUrl,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => errorWidget ?? _buildDefaultAvatar(context),
    );
  }
}
