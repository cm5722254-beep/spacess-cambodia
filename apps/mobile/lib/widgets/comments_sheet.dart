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
  late List<CommentItem> comments;
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    comments = List.from(widget.post.comments);
  }

  void _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final currentUser = ApiService().currentUser;
    final tempComment = CommentItem(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      author: currentUser?.name ?? 'អ្នកប្រើប្រាស់',
      avatar: (currentUser?.avatar != null && currentUser!.avatar.isNotEmpty)
          ? currentUser.avatar
          : '/uploads/admin_avatar.jpg',
      text: text,
      timeAgo: 'មុននេះបន្តិច',
      authorId: currentUser?.id ?? '',
    );

    setState(() {
      comments.insert(0, tempComment);
      widget.post.commentCount += 1;
      _commentController.clear();
      isSending = true;
    });

    final newComment = await ApiService().addComment(widget.post.id, text);
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

  @override
  Widget build(BuildContext context) {
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

          // Comments List
          Expanded(
            child: comments.isEmpty
                ? Center(
                    child: Text(
                      'មិនទាន់មានមតិយោបល់នៅឡើយទេ\nជាអ្នកដំបូងដែលបញ្ចេញមតិ!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.secondaryText),
                    ),
                  )
                : ListView.separated(
                    itemCount: comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = comments[index];
                      final currentUserId = ApiService().currentUser?.id;
                      final isAdmin = ApiService().currentUser?.isAdmin ?? false;
                      final canDelete = isAdmin || (item.authorId.isNotEmpty && item.authorId == currentUserId);

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: MediaImageView(
                              url: item.avatar,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: LiquidGlassContainer(
                              borderRadius: 16,
                              blurSigma: 12,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
                                            fontSize: 13,
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
                                              fontSize: 11,
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
                                  const SizedBox(height: 4),
                                  Text(
                                    item.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.primaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
                    placeholder: 'សរសេរមតិយោបល់...',
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
