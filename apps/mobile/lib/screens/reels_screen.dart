import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/create_reel_sheet.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/media_image_view.dart';
import '../widgets/web_video_player.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final ApiService _api = ApiService();
  final PageController _pageController = PageController();
  List<PostModel> _reels = [];
  bool _isLoading = true;
  int _activePageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadReels();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadReels() async {
    setState(() => _isLoading = true);
    final fetched = await _api.fetchReels();
    if (mounted) {
      setState(() {
        _reels = fetched;
        _isLoading = false;
      });
    }
  }

  void _openCreateReelDialog() {
    CreateReelSheet.show(context, onReelCreated: _loadReels);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: const Color(0xFF000000),
        child: const Center(
          child: CupertinoActivityIndicator(color: CupertinoColors.white, radius: 16),
        ),
      );
    }

    if (_reels.isEmpty) {
      return Container(
        color: const Color(0xFF000000),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.play_circle, size: 64, color: CupertinoColors.white),
              const SizedBox(height: 16),
              Text(
                tr('មិនទាន់មានវីដេអូ Reels នៅឡើយទេ', 'No Reels Available Yet'),
                style: const TextStyle(color: CupertinoColors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                tr('ធ្វើជាមនុស្សដំបូងដែលបង្ហោះ Reel លើ Spaces!', 'Be the first to share a video reel on Spaces!'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                borderRadius: BorderRadius.circular(14),
                onPressed: _openCreateReelDialog,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.plus_circle, color: CupertinoColors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(tr('បង្ហោះ Reel ដំបូង (Create Reel)', 'Create First Reel')),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // Vertical Reel PageView
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _reels.length,
            onPageChanged: (pageIdx) {
              setState(() => _activePageIndex = pageIdx);
            },
            itemBuilder: (context, index) {
              final reel = _reels[index];
              return ValueListenableBuilder<int>(
                valueListenable: _api.activeTabIndexNotifier,
                builder: (ctx, activeTab, _) {
                  final isPageActive = activeTab == 1 && _activePageIndex == index;
                  return _ReelPageItem(
                    reel: reel,
                    isActive: isPageActive,
                    onCommentTap: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (ctx) => CommentsSheet(post: reel),
                      );
                    },
                  );
                },
              );
            },
          ),

          // Header Overlay
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(CupertinoIcons.play_arrow_solid, color: CupertinoColors.white, size: 22),
                    SizedBox(width: 6),
                    Text(
                      'Reels',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: CupertinoColors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                LiquidGlassButton(
                  label: tr('បង្ហោះ Reel', 'Post Reel'),
                  icon: CupertinoIcons.video_camera_solid,
                  variant: LiquidButtonVariant.neutral,
                  borderRadius: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  onPressed: _openCreateReelDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelPageItem extends StatefulWidget {
  final PostModel reel;
  final bool isActive;
  final VoidCallback onCommentTap;

  const _ReelPageItem({
    required this.reel,
    this.isActive = true,
    required this.onCommentTap,
  });

  @override
  State<_ReelPageItem> createState() => _ReelPageItemState();
}

class _ReelPageItemState extends State<_ReelPageItem> {
  bool isLiked = false;
  int likeCount = 0;

  @override
  void initState() {
    super.initState();
    isLiked = widget.reel.isLiked;
    likeCount = widget.reel.likeCount;
  }

  void _toggleLike() async {
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });
    await ApiService().toggleReaction(widget.reel.id, 'like');
  }

  @override
  Widget build(BuildContext context) {
    final videoUrl = widget.reel.videoUrl ?? widget.reel.imageUrl;
    final vLower = (videoUrl ?? '').toLowerCase();
    final isVideo = videoUrl != null &&
        (vLower.contains('.mp4') ||
            vLower.contains('.webm') ||
            vLower.contains('.mov') ||
            vLower.startsWith('data:video') ||
            vLower.contains('/uploads/') ||
            vLower.contains('/storage/object') ||
            vLower.contains('/media/'));
    final media = widget.reel.imageUrl ?? widget.reel.author.avatar;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Viewport / Native Player
        Container(
          color: const Color(0xFF10121A),
          child: isVideo
              ? WebVideoPlayerWidget(
                  videoUrl: videoUrl,
                  autoPlay: widget.isActive,
                  isActive: widget.isActive,
                  parentTabIndex: 1,
                  isLooping: true,
                  showControls: true,
                  bottomControlsPadding: 84,
                  fit: BoxFit.cover,
                )
              : Image.network(
                  media,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1C1E29),
                    child: const Center(
                      child: Icon(CupertinoIcons.play_circle_fill, size: 70, color: CupertinoColors.white),
                    ),
                  ),
                ),
        ),

        // Gradient Vignette Overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.35),
                  Colors.transparent,
                  Colors.black.withOpacity(0.75),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Right Actions Bar (Icons only - Strictly No Emojis!)
        Positioned(
          right: 12,
          bottom: 162,
          child: LiquidGlassContainer(
            borderRadius: 28,
            blurSigma: 18,
            tintColor: const Color(0xFF0A0D14).withValues(alpha: 0.42),
            borderColor: Colors.white.withValues(alpha: 0.22),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            child: Column(
              children: [
                // Like Action
                LiquidGlassPressable(
                  onTap: _toggleLike,
                  child: Column(
                    children: [
                      Icon(
                        isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                        color: isLiked ? const Color(0xFFFF375F) : CupertinoColors.white,
                        size: 30,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$likeCount',
                        style: const TextStyle(color: CupertinoColors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Comment Action
                LiquidGlassPressable(
                  onTap: widget.onCommentTap,
                  child: Column(
                    children: [
                      const Icon(CupertinoIcons.chat_bubble_2_fill, color: CupertinoColors.white, size: 28),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.reel.commentCount}',
                        style: const TextStyle(color: CupertinoColors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Share Action
                Column(
                  children: [
                    const Icon(CupertinoIcons.arrowshape_turn_up_right_fill, color: CupertinoColors.white, size: 26),
                    const SizedBox(height: 3),
                    Text(
                      '${widget.reel.shareCount}',
                      style: const TextStyle(color: CupertinoColors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Rotating Music Disc
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF242738),
                    border: Border.all(color: CupertinoColors.white, width: 2),
                  ),
                  child: const Center(
                    child: Icon(CupertinoIcons.music_note, color: CupertinoColors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Left Author & Details (Liquid Glass Card)
        Positioned(
          left: 12,
          right: 84,
          bottom: 158,
          child: LiquidGlassContainer(
            borderRadius: 22,
            blurSigma: 16,
            tintColor: const Color(0xFF0A0D14).withValues(alpha: 0.44),
            borderColor: Colors.white.withValues(alpha: 0.22),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author Row with VIP Badge
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: MediaImageView(
                        url: widget.reel.author.avatar,
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.reel.author.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (widget.reel.author.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFF0A84FF), size: 15),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.reel.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.reel.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 6),

                // Audio Title Bar
                const Row(
                  children: [
                    Icon(CupertinoIcons.music_note_2, color: CupertinoColors.white, size: 13),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Spaces Cambodia Original Audio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: CupertinoColors.white, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
