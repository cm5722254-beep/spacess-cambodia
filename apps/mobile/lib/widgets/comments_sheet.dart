import 'package:flutter/cupertino.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import 'liquid_glass.dart';
import 'media_image_view.dart';

class CommentsSheet extends StatefulWidget {
  final PostModel post;

  const CommentsSheet({super.key, required this.post});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late List<CommentItem> comments;
  CommentItem? _replyingTo;
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    comments = List.from(widget.post.comments);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _rootThreadId(CommentItem item, Map<String, CommentItem> byId) {
    CommentItem cur = item;
    final visited = <String>{cur.id};
    while (cur.parentId != null && cur.parentId!.isNotEmpty) {
      final parent = byId[cur.parentId!];
      if (parent == null || visited.contains(parent.id)) break;
      visited.add(parent.id);
      cur = parent;
    }
    return cur.id;
  }

  void _startReply(CommentItem item) {
    setState(() => _replyingTo = item);
    _focusNode.requestFocus();
  }

  void _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final currentUser = ApiService().currentUser;
    final replyTarget = _replyingTo;
    final tempComment = CommentItem(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      author: currentUser?.name ?? 'អ្នកប្រើប្រាស់',
      avatar: (currentUser?.avatar != null && currentUser!.avatar.isNotEmpty)
          ? currentUser.avatar
          : '/default_avatar.svg',
      text: text,
      timeAgo: 'មុននេះបន្តិច',
      authorId: currentUser?.id ?? '',
      parentId: replyTarget?.id,
      replyToAuthor: replyTarget?.author,
    );

    setState(() {
      comments.add(tempComment);
      widget.post.commentCount += 1;
      _commentController.clear();
      _replyingTo = null;
      isSending = true;
    });

    final newComment = await ApiService().addComment(
      widget.post.id,
      text,
      parentId: replyTarget?.id,
    );
    if (mounted) {
      setState(() {
        isSending = false;
        if (newComment != null) {
          final idx = comments.indexWhere((c) => c.id == tempComment.id);
          if (idx != -1) {
            comments[idx] = newComment;
          }
        }
      });
    }
  }

  void _confirmDeleteComment(CommentItem item) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('លុបមតិយោបល់'),
        content: const Text('តើអ្នកពិតជាចង់លុបមតិយោបល់នេះមែនទេ?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('បោះបង់'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('លុប'),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ApiService().deleteComment(widget.post.id, item.id);
              if (ok && mounted) {
                setState(() {
                  comments.removeWhere((c) => c.id == item.id);
                  widget.post.commentCount = (widget.post.commentCount - 1).clamp(0, 999999);
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(CommentItem item, {bool isReply = false}) {
    final currentUserId = ApiService().currentUser?.id;
    final isAdmin = ApiService().currentUser?.isAdmin ?? false;
    final canDelete = isAdmin || (item.authorId.isNotEmpty && item.authorId == currentUserId);

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 38 : 0, bottom: isReply ? 8 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(isReply ? 14 : 18),
            child: MediaImageView(
              url: item.avatar,
              width: isReply ? 28 : 36,
              height: isReply ? 28 : 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LiquidGlassContainer(
                  borderRadius: 16,
                  blurSigma: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              item.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isReply ? 12.5 : 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryText,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.timeAgo,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppTheme.tertiaryText,
                                ),
                              ),
                              if (canDelete) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _confirmDeleteComment(item),
                                  child: Icon(
                                    CupertinoIcons.trash,
                                    size: 13,
                                    color: AppTheme.accentCrimson,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (item.replyToAuthor != null && item.replyToAuthor!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '@${item.replyToAuthor}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0A84FF),
                            ),
                          ),
                        ),
                      Text(
                        item.text,
                        style: TextStyle(
                          fontSize: isReply ? 13.5 : 14,
                          color: AppTheme.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 4),
                  child: GestureDetector(
                    onTap: () => _startReply(item),
                    child: Text(
                      'ឆ្លើយតប (Reply)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0A84FF).withOpacity(0.9),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, CommentItem> byId = {for (final c in comments) c.id: c};
    final List<CommentItem> topLevel = [];
    final Map<String, List<CommentItem>> threadReplies = {};

    for (final c in comments) {
      final rootId = _rootThreadId(c, byId);
      if (rootId == c.id) {
        topLevel.add(c);
      } else {
        threadReplies.putIfAbsent(rootId, () => []).add(c);
      }
    }

    return LiquidGlassSheet(
      initialHeightFraction: 0.78,
      child: Column(
        children: [
          Text(
            'មតិយោបល់ (${comments.length})',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryText,
            ),
          ),
          const SizedBox(height: 12),

          // Comments List with Nested Replies
          Expanded(
            child: comments.isEmpty
                ? Center(
                    child: Text(
                      'មិនទាន់មានមតិយោបល់នៅឡើយទេ\nជាអ្នកដំបូងដែលបញ្ចេញមតិ!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.secondaryText),
                    ),
                  )
                : ListView.builder(
                    itemCount: topLevel.length,
                    itemBuilder: (context, index) {
                      final root = topLevel[index];
                      final replies = threadReplies[root.id] ?? [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCommentTile(root, isReply: false),
                          for (final r in replies) _buildCommentTile(r, isReply: true),
                        ],
                      );
                    },
                  ),
          ),

          if (_replyingTo != null)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0A84FF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.arrow_turn_down_right, size: 14, color: Color(0xFF0A84FF)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'កំពុងឆ្លើយតបទៅ ${_replyingTo!.author}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0A84FF),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: const Icon(CupertinoIcons.xmark_circle_fill, size: 16, color: Color(0xFF0A84FF)),
                  ),
                ],
              ),
            ),

          // Input field
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: _commentController,
                    focusNode: _focusNode,
                    placeholder: _replyingTo != null
                        ? 'សរសេរការឆ្លើយតបទៅ ${_replyingTo!.author}...'
                        : 'សរសេរមតិយោបល់...',
                    style: TextStyle(color: AppTheme.primaryText),
                    placeholderStyle: TextStyle(color: AppTheme.tertiaryText),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.fieldBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border, width: 0.7),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                LiquidGlassButton(
                  label: '',
                  icon: CupertinoIcons.arrow_up,
                  isLoading: isSending,
                  padding: const EdgeInsets.all(11),
                  borderRadius: 20,
                  onPressed: isSending ? null : _sendComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
