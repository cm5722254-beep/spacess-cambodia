import 'dart:convert';
import 'package:flutter/cupertino.dart';
import '../models/post_model.dart';
import 'media_image_view.dart';
import 'web_video_player.dart';

class StoryViewerModal extends StatefulWidget {
  final List<StoryModel> stories;
  final int initialIndex;

  const StoryViewerModal({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewerModal> createState() => _StoryViewerModalState();
}

class _StoryViewerModalState extends State<StoryViewerModal>
    with SingleTickerProviderStateMixin {
  late int currentIndex;
  late AnimationController _progressController;
  final TextEditingController _replyController = TextEditingController();

  final List<IconData> quickReactionIcons = [
    CupertinoIcons.heart_fill,
    CupertinoIcons.flame_fill,
    CupertinoIcons.sparkles,
    CupertinoIcons.hand_thumbsup_fill,
    CupertinoIcons.star_fill,
  ];

  final List<Color> quickReactionColors = [
    const Color(0xFFFF2D55),
    const Color(0xFFFF9500),
    const Color(0xFFFFCC00),
    const Color(0xFF007AFF),
    const Color(0xFFFFD60A),
  ];

  Widget _buildStoryMedia(String mediaUrl) {
    if (mediaUrl.trim().isEmpty) {
      return _buildFallbackBg();
    }
    final lower = mediaUrl.toLowerCase();
    final isVideo = lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov') ||
        lower.contains('.mp4') ||
        lower.contains('.webm') ||
        lower.startsWith('data:video');

    if (isVideo) {
      return WebVideoPlayerWidget(
        videoUrl: mediaUrl,
        autoPlay: true,
        isLooping: true,
        showControls: false,
        fit: BoxFit.cover,
      );
    }

    if (mediaUrl.startsWith('data:image')) {
      try {
        final commaIdx = mediaUrl.indexOf(',');
        if (commaIdx != -1) {
          final bytes = base64Decode(mediaUrl.substring(commaIdx + 1));
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackBg(),
          );
        }
      } catch (_) {}
    }

    return Image.network(
      mediaUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: const Color(0xFF0F1016),
          child: const Center(child: CupertinoActivityIndicator(color: CupertinoColors.white, radius: 14)),
        );
      },
      errorBuilder: (_, __, ___) => _buildFallbackBg(),
    );
  }

  Widget _buildFallbackBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1C1E29), Color(0xFF0F1016)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.photo, color: CupertinoColors.white.withOpacity(0.5), size: 46),
            const SizedBox(height: 10),
            Text(
              'Story Media',
              style: TextStyle(color: CupertinoColors.white.withOpacity(0.6), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _nextStory() {
    if (currentIndex < widget.stories.length - 1) {
      setState(() {
        currentIndex++;
      });
      _progressController.reset();
      _progressController.forward();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
      });
      _progressController.reset();
      _progressController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black,
        child: Center(
          child: CupertinoButton(
            child: const Text('បិទ (Close)'),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );
    }

    final story = widget.stories[currentIndex];

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image/Video Viewport
            Positioned.fill(
              child: GestureDetector(
                onTapUp: (details) {
                  final width = MediaQuery.of(context).size.width;
                  if (details.globalPosition.dx < width / 3) {
                    _previousStory();
                  } else {
                    _nextStory();
                  }
                },
                child: _buildStoryMedia(story.imageUrl),
              ),
            ),

            // Gradient overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        CupertinoColors.black.withOpacity(0.65),
                        CupertinoColors.transparent,
                        CupertinoColors.black.withOpacity(0.85),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.35, 0.85],
                    ),
                  ),
                ),
              ),
            ),

            // Top Header: Progress indicators & Author info
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress segments
                      Row(
                        children: List.generate(widget.stories.length, (index) {
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 3,
                              decoration: BoxDecoration(
                                color: CupertinoColors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: index == currentIndex
                                  ? AnimatedBuilder(
                                      animation: _progressController,
                                      builder: (context, child) {
                                        return FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: _progressController.value,
                                          child: Container(
                                            color: CupertinoColors.white,
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: index < currentIndex
                                          ? CupertinoColors.white
                                          : CupertinoColors.transparent,
                                    ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),

                      // Author Row
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: MediaImageView(
                              url: story.authorAvatar.isNotEmpty ? story.authorAvatar : '/default_avatar.svg',
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  story.authorName,
                                  style: const TextStyle(
                                    color: CupertinoColors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      CupertinoIcons.location_solid,
                                      color: Color(0xFF34C759),
                                      size: 11,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${story.city} • ${story.timeAgo}',
                                      style: TextStyle(
                                        color: CupertinoColors.white.withOpacity(0.8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: const Icon(
                              CupertinoIcons.xmark_circle_fill,
                              color: CupertinoColors.white,
                              size: 26,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Caption & Quick Reaction Reply Bar
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Caption
                    if (story.caption.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          story.caption,
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),

                    // Quick Reactions (Icons only - Strictly No Emojis)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(quickReactionIcons.length, (idx) {
                        final icon = quickReactionIcons[idx];
                        final color = quickReactionColors[idx];
                        return GestureDetector(
                          onTap: () {
                            _replyController.text = 'Reacted';
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: CupertinoColors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),

                    // Reply bar
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            controller: _replyController,
                            placeholder: 'ឆ្លើយតបទៅកាន់ ${story.authorName}...',
                            placeholderStyle: TextStyle(
                              color: CupertinoColors.white.withOpacity(0.6),
                            ),
                            style: const TextStyle(color: CupertinoColors.white),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: CupertinoColors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: const EdgeInsets.all(10),
                          color: const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(22),
                          child: const Icon(CupertinoIcons.arrow_up, size: 18, color: CupertinoColors.white),
                          onPressed: () {
                            if (_replyController.text.isNotEmpty) {
                              _replyController.clear();
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
