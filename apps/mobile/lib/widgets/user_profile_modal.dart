import 'package:flutter/cupertino.dart';
import '../models/post_model.dart';
import '../screens/chat_screen.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import 'media_image_view.dart';

class UserProfileModal extends StatefulWidget {
  final Author author;

  const UserProfileModal({super.key, required this.author});

  @override
  State<UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends State<UserProfileModal> {
  late bool isFollowing;
  late int followerCount;
  int followingCount = 0;
  String? _bio;
  String? _location;
  String? _bannerUrl;
  String? _storeName;
  String? _storeTagline;
  String? _storeThemeColor;
  String? _storeBannerUrl;
  List<PostModel> _publicPosts = [];
  bool _isLoadingExtra = true;
  bool isToggling = false;
  bool isOpeningChat = false;

  @override
  void initState() {
    super.initState();
    isFollowing = widget.author.isFollowing;
    followerCount = widget.author.followerCount;
    followingCount = widget.author.followingCount;
    _bio = widget.author.bio;
    _location = widget.author.location;
    _loadPublicDetails();
  }

  Future<void> _loadPublicDetails() async {
    final profile = await ApiService().fetchPublicProfile(widget.author.username.isNotEmpty
        ? widget.author.username
        : widget.author.id);
    final targetId = (profile?['id']?.toString().isNotEmpty ?? false)
        ? profile!['id'].toString()
        : widget.author.id;
    final posts = targetId.isNotEmpty
        ? await ApiService().fetchFeed(authorId: targetId)
        : <PostModel>[];
    if (!mounted) return;
    setState(() {
      if (profile != null) {
        if (profile['followerCount'] is num) followerCount = (profile['followerCount'] as num).toInt();
        if (profile['followingCount'] is num) followingCount = (profile['followingCount'] as num).toInt();
        if (profile['isFollowing'] is bool) isFollowing = profile['isFollowing'] as bool;
        _bio = profile['bio']?.toString() ?? _bio;
        _location = profile['location']?.toString() ?? _location;
        _bannerUrl = profile['bannerUrl']?.toString();
        _storeName = profile['storeName']?.toString();
        _storeTagline = profile['storeTagline']?.toString();
        _storeThemeColor = profile['storeThemeColor']?.toString();
        _storeBannerUrl = profile['storeBannerUrl']?.toString();
      }
      _publicPosts = posts;
      _isLoadingExtra = false;
    });
  }

  void _toggleFollow() async {
    final prevFollowing = isFollowing;
    final prevCount = followerCount;
    setState(() {
      isFollowing = !isFollowing;
      followerCount += isFollowing ? 1 : -1;
    });

    final newStatus = await ApiService().toggleFollow(widget.author.username);
    if (newStatus == null && mounted) {
      setState(() {
        isFollowing = prevFollowing;
        followerCount = prevCount;
      });
    } else if (newStatus != null && mounted) {
      setState(() {
        isFollowing = newStatus;
      });
    }
  }

  void _openDirectChat() async {
    final me = ApiService().currentUser;
    if (me == null || me.id == widget.author.id || isOpeningChat) return;
    setState(() => isOpeningChat = true);
    final rootNav = Navigator.of(context, rootNavigator: true);
    final chat = await ApiService().getOrCreateDirectChat(widget.author.id);
    if (!mounted) return;
    setState(() => isOpeningChat = false);
    if (chat != null) {
      Navigator.pop(context);
      rootNav.push(
        CupertinoPageRoute(builder: (_) => ChatConversationScreen(chat: chat)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = ApiService().currentUser?.id == widget.author.id;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppTheme.modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32),
                Text(
                  '@${widget.author.username}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryText,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.clear_circled_solid, color: CupertinoColors.systemGrey3),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_bannerUrl != null && _bannerUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: MediaImageView(
                      url: _bannerUrl!,
                      height: 115,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                // Avatar + Name (Strict Public Read-Only Profile)
                Center(
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(46),
                        child: MediaImageView(
                          url: widget.author.avatar,
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.author.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryText,
                              ),
                            ),
                          ),
                          if (widget.author.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(CupertinoIcons.checkmark_seal_fill, size: 18, color: Color(0xFF007AFF)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.location_solid, size: 14, color: Color(0xFF34C759)),
                          const SizedBox(width: 4),
                          Text(
                            (_location != null && _location!.isNotEmpty)
                                ? _location!
                                : widget.author.location,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF34C759),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Follow + Message Actions Row
                if (!isMe)
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          color: isFollowing ? AppTheme.surfaceBg : const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(14),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onPressed: _toggleFollow,
                          child: Text(
                            isFollowing ? tr('កំពុង Follow', 'Following') : tr('+ Follow តាមដាន', '+ Follow'),
                            style: TextStyle(
                              color: isFollowing ? AppTheme.primaryText : CupertinoColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CupertinoButton(
                          color: const Color(0xFF34C759),
                          borderRadius: BorderRadius.circular(14),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onPressed: isOpeningChat ? null : _openDirectChat,
                          child: isOpeningChat
                              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(CupertinoIcons.chat_bubble_fill, size: 16, color: CupertinoColors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      tr('ផ្ញើសារ (Chat)', 'Message'),
                                      style: const TextStyle(
                                        color: CupertinoColors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                // Stats Row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border, width: 0.7),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat('Followers', '$followerCount'),
                      _buildStat('Following', '$followingCount'),
                      _buildStat(tr('ផុស', 'Posts'), '${_publicPosts.length}'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Bio
                Text(
                  tr('អំពី (About):', 'About:'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                ),
                const SizedBox(height: 6),
                Text(
                  (_bio != null && _bio!.isNotEmpty)
                      ? _bio!
                      : tr(
                          'សមាជិកបណ្ដាញសង្គម Spaces Cambodia។',
                          'Member of Spaces Cambodia.',
                        ),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppTheme.secondaryText,
                  ),
                ),

                if (_storeName != null && _storeName!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border, width: 0.7),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_storeBannerUrl != null && _storeBannerUrl!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: MediaImageView(
                              url: _storeBannerUrl!,
                              height: 90,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.bag_fill,
                              size: 16,
                              color: (_storeThemeColor != null && _storeThemeColor!.startsWith('#'))
                                  ? Color(int.parse(_storeThemeColor!.replaceFirst('#', '0xFF')))
                                  : const Color(0xFF0A84FF),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _storeName!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_storeTagline != null && _storeTagline!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _storeTagline!,
                            style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                Text(
                  tr('ការបង្ហោះសាធារណៈ (${_publicPosts.length})', 'Public Posts (${_publicPosts.length})'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                ),
                const SizedBox(height: 10),
                if (_isLoadingExtra)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CupertinoActivityIndicator()))
                else if (_publicPosts.isEmpty)
                  Text(
                    tr('មិនទាន់មានការបង្ហោះនៅឡើយទេ។', 'No public posts yet.'),
                    style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
                  )
                else
                  ..._publicPosts.take(15).map((p) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border, width: 0.6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.timeAgo,
                              style: TextStyle(fontSize: 11, color: AppTheme.tertiaryText),
                            ),
                            const SizedBox(height: 6),
                            if (p.content.isNotEmpty)
                              Text(
                                p.content,
                                style: TextStyle(fontSize: 13.5, color: AppTheme.primaryText, height: 1.4),
                              ),
                            if (p.imageUrl != null && p.imageUrl!.isNotEmpty && !p.isReel) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: MediaImageView(
                                  url: p.imageUrl!,
                                  width: double.infinity,
                                  height: 150,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.secondaryText,
          ),
        ),
      ],
    );
  }
}
