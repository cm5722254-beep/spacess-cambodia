import 'package:flutter/cupertino.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import 'liquid_glass.dart';
import 'media_image_view.dart';
import 'user_profile_modal.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onCommentTap;
  final VoidCallback? onPostDeleted;
  final VoidCallback? onPostUpdated;

  const PostCard({
    super.key,
    required this.post,
    this.onCommentTap,
    this.onPostDeleted,
    this.onPostUpdated,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool isLiked;
  late int likeCount;
  late String selectedReaction;
  bool showReactionPicker = false;

  final Map<String, IconData> reactionIcons = {
    'LIKE': CupertinoIcons.hand_thumbsup_fill,
    'LOVE': CupertinoIcons.heart_fill,
    'CELEBRATE': CupertinoIcons.sparkles,
    'HAHA': CupertinoIcons.smiley_fill,
    'WOW': CupertinoIcons.star_fill,
    'SAD': CupertinoIcons.cloud_rain_fill,
  };

  final Map<String, Color> reactionColors = {
    'LIKE': const Color(0xFF007AFF),
    'LOVE': const Color(0xFFFF2D55),
    'CELEBRATE': const Color(0xFFFF9500),
    'HAHA': const Color(0xFFFFCC00),
    'WOW': const Color(0xFFAF52DE),
    'SAD': const Color(0xFF8E8E93),
  };

  @override
  void initState() {
    super.initState();
    isLiked = widget.post.isLiked;
    likeCount = widget.post.likeCount;
    selectedReaction = widget.post.selectedReaction;
  }

  void _applyReaction(String reactionType) async {
    setState(() {
      if (isLiked && selectedReaction == reactionType) {
        isLiked = false;
        likeCount = (likeCount - 1).clamp(0, 999999);
      } else {
        if (!isLiked) likeCount += 1;
        isLiked = true;
        selectedReaction = reactionType;
      }
      showReactionPicker = false;
    });

    await ApiService().toggleReaction(widget.post.id, reactionType);
  }

  void _toggleBookmark() async {
    setState(() {
      widget.post.isBookmarked = !widget.post.isBookmarked;
    });
    final res = await ApiService().toggleBookmark(widget.post.id);
    if (mounted) {
      setState(() {
        widget.post.isBookmarked = res;
      });
    }
  }

  void _confirmDeletePost() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(tr('លុបការបង្ហោះ', 'Delete Post')),
        content: Text(tr(
          'តើអ្នកពិតជាចង់លុបការបង្ហោះនេះមែនទេ? សកម្មភាពនេះមិនអាចត្រឡប់វិញបានទេ។',
          'Are you sure you want to delete this post? This cannot be undone.',
        )),
        actions: [
          CupertinoDialogAction(
            child: Text(tr('បោះបង់', 'Cancel')),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(tr('លុប', 'Delete')),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ApiService().deletePost(widget.post.id);
              if (ok && widget.onPostDeleted != null) {
                widget.onPostDeleted!();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showEditPostDialog() {
    final controller = TextEditingController(text: widget.post.content);
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(tr('កែសម្រួលការបង្ហោះ', 'Edit Post')),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            maxLines: 4,
            padding: const EdgeInsets.all(10),
            placeholder: tr('កែសម្រួលខ្លឹមសារ...', 'Edit content...'),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(tr('បោះបង់', 'Cancel')),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            child: Text(tr('រក្សាទុក', 'Save')),
            onPressed: () async {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty && newContent != widget.post.content) {
                Navigator.pop(ctx);
                final ok = await ApiService().updatePost(widget.post.id, content: newContent);
                if (ok && mounted) {
                  if (widget.onPostUpdated != null) {
                    widget.onPostUpdated!();
                  }
                }
              } else {
                Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
  }

  void _openPostOptions() {
    final currentUserId = ApiService().currentUser?.id;
    final isAuthor = currentUserId == widget.post.author.id;
    final isAdmin = ApiService().currentUser?.isAdmin ?? false;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(tr('ជម្រើសការបង្ហោះ', 'Post Options')),
        actions: [
          CupertinoActionSheetAction(
            child: Text(tr('ចម្លងតំណភ្ជាប់ (Copy Link)', 'Copy Link')),
            onPressed: () => Navigator.pop(ctx),
          ),
          if (isAuthor || isAdmin) ...[
            CupertinoActionSheetAction(
              child: Text(tr('កែសម្រួលការបង្ហោះ (Edit Post)', 'Edit Post')),
              onPressed: () {
                Navigator.pop(ctx);
                _showEditPostDialog();
              },
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: Text(tr('លុបការបង្ហោះ (Delete Post)', 'Delete Post')),
              onPressed: () {
                Navigator.pop(ctx);
                _confirmDeletePost();
              },
            ),
          ] else ...[
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: Text(tr('រាយការណ៍ការបង្ហោះ (Report)', 'Report Post')),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(tr('បោះបង់', 'Cancel')),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _openUserProfile() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => UserProfileModal(author: widget.post.author),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spaceColor = Color(int.parse(widget.post.space.color.replaceFirst('#', '0xFF')));
    final hPad = ResponsiveLayout.horizontalPadding(context);

    return LiquidGlassContainer(
      margin: EdgeInsets.symmetric(horizontal: hPad, vertical: 7),
      borderRadius: 24,
      blurSigma: 18,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Boosted Post Badge
              if (widget.post.isBoosted)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.sparkles, size: 13, color: CupertinoColors.white),
                      SizedBox(width: 5),
                      Text(
                        'VIP Boosted Post',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CupertinoColors.white),
                      ),
                    ],
                  ),
                ),

              // Header: Space tag & Circle badge
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    // Space Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: spaceColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: spaceColor.withOpacity(0.3), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: spaceColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.post.space.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: spaceColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Circle Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.post.circle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Author Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _openUserProfile,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: MediaImageView(
                          url: widget.post.author.avatar,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: _openUserProfile,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.post.author.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryText,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.post.author.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    CupertinoIcons.checkmark_seal_fill,
                                    size: 16,
                                    color: Color(0xFF007AFF),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '@${widget.post.author.username} • ${widget.post.timeAgo}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.secondaryText,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(CupertinoIcons.location_solid, size: 11, color: Color(0xFF34C759)),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  widget.post.city,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF34C759),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _openPostOptions,
                      child: const Icon(
                        CupertinoIcons.ellipsis,
                        color: CupertinoColors.secondaryLabel,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(
                  widget.post.content,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: AppTheme.primaryText,
                  ),
                ),
              ),

              // Image
              if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: MediaImageView(
                      url: widget.post.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              // Tags
              if (widget.post.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: widget.post.tags.map((tag) {
                      return Text(
                        '#$tag',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF007AFF),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 8),
              Container(height: 0.5, color: AppTheme.divider),

              // Action Buttons: Reactions, Comment, Share, Bookmark
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Reaction Button
                    GestureDetector(
                      onLongPress: () {
                        setState(() {
                          showReactionPicker = !showReactionPicker;
                        });
                      },
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        onPressed: () {
                          if (isLiked) {
                            _applyReaction(selectedReaction);
                          } else {
                            _applyReaction('LIKE');
                          }
                        },
                        child: Row(
                          children: [
                            if (isLiked && reactionIcons.containsKey(selectedReaction)) ...[
                              Icon(reactionIcons[selectedReaction]!, size: 18, color: reactionColors[selectedReaction]),
                              const SizedBox(width: 4),
                            ] else ...[
                              Icon(
                                CupertinoIcons.hand_thumbsup,
                                color: AppTheme.secondaryText,
                                size: 19,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              likeCount >= 0 ? '$likeCount' : '',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isLiked ? (reactionColors[selectedReaction] ?? const Color(0xFF007AFF)) : AppTheme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Comment Button
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      onPressed: widget.onCommentTap,
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.chat_bubble,
                            color: AppTheme.secondaryText,
                            size: 19,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.post.commentCount >= 0 ? '${widget.post.commentCount}' : '',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Share Button
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      onPressed: () {
                        showCupertinoModalPopup(
                          context: context,
                          builder: (ctx) => CupertinoActionSheet(
                            title: Text(tr('ចែករំលែកការបង្ហោះ (Share Post)', 'Share Post')),
                            actions: [
                              CupertinoActionSheetAction(
                                child: Text(tr('ចម្លងតំណភ្ជាប់ (Copy Link)', 'Copy Link')),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                              CupertinoActionSheetAction(
                                child: Text(tr('ចែករំលែកទៅកាន់ Space ផ្សេងទៀត', 'Share to Another Space')),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                            cancelButton: CupertinoActionSheetAction(
                              isDestructiveAction: true,
                              child: Text(tr('បោះបង់', 'Cancel')),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.arrow_turn_up_right,
                            color: AppTheme.secondaryText,
                            size: 19,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tr('ចែករំលែក', 'Share'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bookmark Button
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      onPressed: _toggleBookmark,
                      child: Icon(
                        widget.post.isBookmarked ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                        color: widget.post.isBookmarked ? const Color(0xFF007AFF) : AppTheme.secondaryText,
                        size: 19,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Multi-reaction bar popup with CupertinoIcons (strictly NO raw emojis!)
          if (showReactionPicker)
            Positioned(
              bottom: 48,
              left: 12,
              child: LiquidGlassContainer(
                borderRadius: 28,
                blurSigma: 22,
                elevated: true,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: reactionIcons.entries.map((entry) {
                    final color = reactionColors[entry.key] ?? const Color(0xFF007AFF);
                    return LiquidGlassPressable(
                      pressedScale: 0.84,
                      onTap: () => _applyReaction(entry.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(entry.value, size: 22, color: color),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
