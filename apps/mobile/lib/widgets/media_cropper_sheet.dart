import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import 'liquid_glass.dart';

class MediaCropperSheet extends StatefulWidget {
  final String imageUrl;
  final bool isCircle; // true for Avatar, false for Banner
  final String title;

  const MediaCropperSheet({
    super.key,
    required this.imageUrl,
    this.isCircle = true,
    this.title = 'កែសម្រួលទីតាំងរូបភាព (Crop & Position)',
  });

  static Future<String?> show(
    BuildContext context, {
    required String imageUrl,
    bool isCircle = true,
    String? title,
  }) {
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => MediaCropperSheet(
        imageUrl: imageUrl,
        isCircle: isCircle,
        title: title ?? (isCircle ? 'កែសម្រួលរូប Profile' : 'កែសម្រួលរូប Banner'),
      ),
    );
  }

  @override
  State<MediaCropperSheet> createState() => _MediaCropperSheetState();
}

class _MediaCropperSheetState extends State<MediaCropperSheet> {
  final TransformationController _transformController = TransformationController();
  double _zoomLevel = 1.0;
  int _rotationQuarterTurns = 0;

  Widget _buildImage() {
    final url = widget.imageUrl.trim();
    if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        if (commaIdx != -1) {
          final bytes = base64Decode(url.substring(commaIdx + 1));
          return Image.memory(bytes, fit: BoxFit.contain);
        }
      } catch (_) {}
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(CupertinoIcons.photo, size: 50, color: CupertinoColors.systemGrey),
      ),
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    final frameWidth = size.width * 0.85;
    final frameHeight = widget.isCircle ? frameWidth : frameWidth * 0.48;

    return Container(
      height: size.height * 0.88,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161822) : CupertinoColors.systemBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4.5,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF48484A) : const Color(0xFFD1D1D6),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: const Text('បោះបង់', style: TextStyle(color: CupertinoColors.systemGrey)),
              ),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryText,
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  // In client-side preview, the user has aligned their viewport
                  Navigator.pop(context, widget.imageUrl);
                },
                child: const Text(
                  'រួចរាល់',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Guidance caption
          Text(
            widget.isCircle
                ? 'អូសដើម្បីតម្រង់ទីតាំង ឬពង្រីក/បង្រួមឱ្យត្រូវនឹងរង្វង់ Profile'
                : 'អូសដើម្បីតម្រង់ទីតាំង ឬពង្រីក/បង្រួមឱ្យត្រូវនឹងស៊ុម Banner',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppTheme.secondaryText),
          ),

          const SizedBox(height: 16),

          // Viewport & Cropper Frame
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Dark background
                Container(
                  color: Colors.black,
                  width: double.infinity,
                  height: double.infinity,
                ),

                // Interactive Pan & Zoom Area
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.8,
                    maxScale: 3.5,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    onInteractionUpdate: (_) {
                      final scale = _transformController.value.getMaxScaleOnAxis();
                      if (scale != _zoomLevel) {
                        setState(() => _zoomLevel = scale);
                      }
                    },
                    child: RotatedBox(
                      quarterTurns: _rotationQuarterTurns,
                      child: _buildImage(),
                    ),
                  ),
                ),

                // Mask Overlay to show clear focus area
                IgnorePointer(
                  child: Container(
                    width: frameWidth,
                    height: frameHeight,
                    decoration: BoxDecoration(
                      shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: widget.isCircle ? null : BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF007AFF),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.55),
                          spreadRadius: 2000,
                        ),
                      ],
                    ),
                  ),
                ),

                // Crosshair guidance grid lines
                IgnorePointer(
                  child: SizedBox(
                    width: frameWidth,
                    height: frameHeight,
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 1,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Zoom & Rotate Controls
          Row(
            children: [
              const Icon(CupertinoIcons.zoom_out, size: 18, color: Color(0xFF007AFF)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF007AFF),
                    thumbColor: const Color(0xFF007AFF),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _zoomLevel.clamp(0.8, 3.5),
                    min: 0.8,
                    max: 3.5,
                    onChanged: (val) {
                      setState(() {
                        _zoomLevel = val;
                        final matrix = Matrix4.identity()..scale(val);
                        _transformController.value = matrix;
                      });
                    },
                  ),
                ),
              ),
              const Icon(CupertinoIcons.zoom_in, size: 18, color: Color(0xFF007AFF)),
              const SizedBox(width: 10),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                color: isDark ? const Color(0xFF2C2F3E) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(12),
                minSize: 32,
                onPressed: () {
                  setState(() => _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4);
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.rotate_right, size: 16, color: Color(0xFF007AFF)),
                    SizedBox(width: 4),
                    Text(
                      'បង្វិល',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF007AFF)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Apply Button
          LiquidGlassButton(
            label: 'កំណត់ និង រក្សាទុក (Save Position)',
            icon: CupertinoIcons.checkmark_alt_circle_fill,
            expand: true,
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(vertical: 14),
            onPressed: () {
              Navigator.pop(context, widget.imageUrl);
            },
          ),
        ],
      ),
    );
  }
}
