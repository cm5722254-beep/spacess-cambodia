import 'package:flutter/cupertino.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../utils/media_picker_helper.dart';
import '../widgets/post_card.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/story_viewer.dart';
import '../widgets/media_image_view.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/pwa_install_banner.dart';
import 'chat_screen.dart';
import 'marketplace_screen.dart';
import 'stream_watch_screen.dart';

class HomeFeedScreen extends StatefulWidget {
  final VoidCallback? onNotificationTap;

  const HomeFeedScreen({super.key, this.onNotificationTap});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  List<PostModel> posts = [];
  List<SpaceModel> spaces = [];
  List<StoryModel> stories = [];
  List<PublicUserModel> searchedUsers = [];
  bool isLoading = true;
  String selectedSpaceFilter = 'all';
  String selectedCityFilter = '';
  bool focusMode = false;
  bool isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final List<String> cityFilters = [
    'Phnom Penh',
    'Siem Reap',
    'Kampot',
    'Battambang',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      isLoading = true;
      if (!isSearching) searchedUsers = [];
    });
    final fetchedSpaces = await ApiService().fetchSpaces();
    final fetchedStories = await ApiService().fetchStories();
    final fetchedPosts = await ApiService().fetchFeed(
      spaceId: selectedSpaceFilter,
      city: selectedCityFilter,
      isDigest: focusMode,
    );

    if (mounted) {
      setState(() {
        spaces = fetchedSpaces;
        stories = fetchedStories;
        posts = fetchedPosts;
        isLoading = false;
      });
    }
  }

  void _onSpaceFilterChanged(String filter) async {
    setState(() {
      selectedSpaceFilter = filter;
      isLoading = true;
    });
    final fetchedPosts = await ApiService().fetchFeed(
      spaceId: filter,
      city: selectedCityFilter,
      isDigest: focusMode,
    );
    if (mounted) {
      setState(() {
        posts = fetchedPosts;
        isLoading = false;
      });
    }
  }

  void _onCityFilterChanged(String city) async {
    setState(() {
      selectedCityFilter = (selectedCityFilter == city) ? '' : city;
      isLoading = true;
    });
    final fetchedPosts = await ApiService().fetchFeed(
      spaceId: selectedSpaceFilter,
      city: selectedCityFilter,
      isDigest: focusMode,
    );
    if (mounted) {
      setState(() {
        posts = fetchedPosts;
        isLoading = false;
      });
    }
  }

  void _toggleFocusMode() async {
    final newMode = !focusMode;
    setState(() => focusMode = newMode);
    await ApiService().updateSettings(focusMode: newMode);
    _loadInitialData();
  }

  void _onSearch(String query) async {
    if (query.trim().isEmpty) {
      searchedUsers = [];
      _loadInitialData();
      return;
    }
    setState(() => isLoading = true);
    final results = await Future.wait([
      ApiService().search(query.trim()),
      ApiService().searchUsers(query.trim()),
    ]);
    if (mounted) {
      final feedRes = results[0] as Map<String, dynamic>;
      final usersRes = results[1] as List<PublicUserModel>;
      setState(() {
        posts = (feedRes['posts'] as List<PostModel>?) ?? [];
        searchedUsers = usersRes;
        isLoading = false;
      });
    }
  }

  void _openStoryViewer(int index) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => StoryViewerModal(
          stories: stories,
          initialIndex: index,
        ),
      ),
    );
  }

  void _openCommentsModal(PostModel post) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CommentsSheet(post: post),
    );
  }

  void _showAddStoryDialog() {
    final imageCtrl = TextEditingController();
    final captionCtrl = TextEditingController();
    String? importedStoryMedia;
    bool isImporting = false;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStoryModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 16,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: AppTheme.modalBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  tr('បន្ថែម Story ថ្មី (Add Story)', 'Add 24h Story'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                ),
                const SizedBox(height: 16),

                // Device Photo Import
                if (importedStoryMedia != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: MediaImageView(url: importedStoryMedia!, height: 160, width: double.infinity, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setStoryModalState(() => importedStoryMedia = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Color(0xCC000000), shape: BoxShape.circle),
                            child: const Icon(CupertinoIcons.xmark, color: CupertinoColors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  CupertinoButton(
                    color: AppTheme.surfaceBg,
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onPressed: isImporting
                        ? null
                        : () async {
                            setStoryModalState(() => isImporting = true);
                            final media = await MediaPickerHelper.pickAndUploadMedia(accept: 'image/*,video/*');
                            setStoryModalState(() {
                              isImporting = false;
                              if (media != null && media.isNotEmpty) {
                                importedStoryMedia = media;
                              }
                            });
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.camera_fill, size: 20, color: Color(0xFF007AFF)),
                        const SizedBox(width: 8),
                        Text(
                          tr('ជ្រើសរើសរូបពីទូរស័ព្ទ / ឧបករណ៍', 'Import Story Photo from Device'),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF007AFF)),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: imageCtrl,
                  placeholder: tr('ឬ បញ្ចូលតំណភ្ជាប់រូបភាព (Or Paste Image URL)', 'Or paste image URL...'),
                  style: TextStyle(color: AppTheme.primaryText),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.fieldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border, width: 0.6),
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: captionCtrl,
                  placeholder: tr('សរសេរអ្វីមួយសម្រាប់ Story...', 'Write caption...'),
                  style: TextStyle(color: AppTheme.primaryText),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.fieldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border, width: 0.6),
                  ),
                ),
                const SizedBox(height: 18),
                CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(12),
                  child: Text(tr('បង្ហោះ Story ឥឡូវនេះ (Share Story)', 'Share Story')),
                  onPressed: () async {
                    final finalUrl = importedStoryMedia ??
                        (imageCtrl.text.trim().isNotEmpty
                            ? imageCtrl.text.trim()
                            : 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=800&q=80');
                    Navigator.pop(ctx);
                    final ok = await ApiService().createStory(
                      imageUrl: finalUrl,
                      caption: captionCtrl.text.trim().isEmpty ? null : captionCtrl.text.trim(),
                    );
                    if (ok) {
                      _loadInitialData();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ApiService().isDarkModeNotifier,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: LanguageService().languageNotifier,
          builder: (context, currentLang, _) {
            return CupertinoPageScaffold(
      backgroundColor: AppTheme.scaffoldBg,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // iOS Translucent Large Title Navigation Bar
          CupertinoSliverNavigationBar(
            backgroundColor: AppTheme.navBarBg,
            largeTitle: Row(
              children: [
                // Spaces Cambodia Logo Badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5856D6), Color(0xFF007AFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5856D6).withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.circle_grid_hex_fill,
                      color: CupertinoColors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Spaces Cambodia',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    Text(
                      focusMode ? 'Calm Focus Mode' : tr('កម្ពុជា សង្គមឌីជីថល', 'Cambodia Digital Space'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: focusMode ? const Color(0xFF34C759) : AppTheme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // PWA Install Pill (Web only, hidden when already installed)
                const PwaInstallBanner(compact: true),

                // Search toggle
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minSize: 36,
                  child: Icon(
                    isSearching ? CupertinoIcons.xmark_circle_fill : CupertinoIcons.search,
                    color: const Color(0xFF007AFF),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      isSearching = !isSearching;
                      if (!isSearching) {
                        _searchController.clear();
                        _loadInitialData();
                      }
                    });
                  },
                ),

                // Notification Bell
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minSize: 36,
                  onPressed: widget.onNotificationTap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(CupertinoIcons.bell_fill, color: Color(0xFF007AFF), size: 20),
                      Positioned(
                        top: -1,
                        right: -1,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick More / Actions Menu (Focus Mode, Marketplace, Live Stream)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minSize: 36,
                  child: const Icon(
                    CupertinoIcons.ellipsis_circle_fill,
                    color: Color(0xFF007AFF),
                    size: 20,
                  ),
                  onPressed: () {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (ctx) => CupertinoActionSheet(
                        title: const Text('Spaces Shortcuts & Quick Access'),
                        actions: [
                          CupertinoActionSheetAction(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _toggleFocusMode();
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.leaf_arrow_circlepath,
                                  color: focusMode ? const Color(0xFF34C759) : const Color(0xFF007AFF),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(focusMode ? 'បិទ Focus Mode' : 'បើក Focus Mode (Calm Digest)'),
                              ],
                            ),
                          ),
                          CupertinoActionSheetAction(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                CupertinoPageRoute(builder: (_) => const MarketplaceScreen()),
                              );
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.bag_fill, color: Color(0xFF007AFF), size: 18),
                                SizedBox(width: 8),
                                Text('ផ្សារទំនិញ (Marketplace)'),
                              ],
                            ),
                          ),
                          CupertinoActionSheetAction(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                CupertinoPageRoute(builder: (_) => const StreamWatchScreen()),
                              );
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.play_rectangle_fill, color: Color(0xFFFF2D55), size: 18),
                                SizedBox(width: 8),
                                Text('ការផ្សាយបន្តផ្ទាល់ (Live Streams)'),
                              ],
                            ),
                          ),
                        ],
                        cancelButton: CupertinoActionSheetAction(
                          isDefaultAction: true,
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('បិទ'),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Pull-to-refresh
          CupertinoSliverRefreshControl(
            onRefresh: _loadInitialData,
          ),

          // Search Box Sliver (if toggled)
          if (isSearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Column(
                  children: [
                    CupertinoSearchTextField(
                      controller: _searchController,
                      style: TextStyle(color: AppTheme.primaryText),
                      backgroundColor: AppTheme.fieldBg,
                      placeholder: tr(
                        'ស្វែងរកអ្នកប្រើប្រាស់ ឬ ការបង្ហោះ (ឧ. សុខ ជាតិ)...',
                        'Search people or posts (e.g. Sok Cheat)...',
                      ),
                      onSubmitted: _onSearch,
                      onSuffixTap: () {
                        _searchController.clear();
                        searchedUsers = [];
                        _loadInitialData();
                      },
                    ),
                    if (searchedUsers.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border, width: 0.8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('អ្នកប្រើប្រាស់ដែលរកឃើញ (${searchedUsers.length})', 'People (${searchedUsers.length})'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...searchedUsers.map((u) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: MediaImageView(
                                          url: u.avatar,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    u.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppTheme.primaryText,
                                                    ),
                                                  ),
                                                ),
                                                if (u.isVerified) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(CupertinoIcons.checkmark_seal_fill,
                                                      size: 13, color: Color(0xFF007AFF)),
                                                ],
                                              ],
                                            ),
                                            Text(
                                              '@${u.username}',
                                              style: TextStyle(fontSize: 11, color: AppTheme.secondaryText),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (u.friendStatus == 'NONE')
                                        CupertinoButton(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          minSize: 28,
                                          color: const Color(0xFF007AFF).withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(10),
                                          onPressed: () async {
                                            setState(() => u.friendStatus = 'PENDING_SENT');
                                            await ApiService().sendFriendRequest(u.id);
                                          },
                                          child: Text(
                                            tr('+ មិត្ត', '+ Add'),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF007AFF),
                                            ),
                                          ),
                                        )
                                      else if (u.friendStatus == 'PENDING_SENT')
                                        Text(
                                          tr('បានស្នើ', 'Sent'),
                                          style: TextStyle(fontSize: 11, color: AppTheme.secondaryText),
                                        )
                                      else if (u.friendStatus == 'ACCEPTED')
                                        Text(
                                          tr('មិត្តភក្តិ', 'Friend'),
                                          style: const TextStyle(
                                              fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF34C759)),
                                        ),
                                      const SizedBox(width: 6),
                                      CupertinoButton(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        minSize: 28,
                                        color: const Color(0xFF007AFF),
                                        borderRadius: BorderRadius.circular(10),
                                        onPressed: () async {
                                          final chat = await ApiService().getOrCreateDirectChat(u.id);
                                          if (chat != null && context.mounted) {
                                            Navigator.of(context, rootNavigator: true).push(
                                              CupertinoPageRoute(builder: (_) => ChatConversationScreen(chat: chat)),
                                            );
                                          }
                                        },
                                        child: Text(
                                          tr('ឆាត', 'Chat'),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: CupertinoColors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Instagram/Facebook-style 24h Stories Bar
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              height: 104,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: stories.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // My Story (+) interactive item
                    final curUser = ApiService().currentUser;
                    final avatarUrl = (curUser?.avatar != null && curUser!.avatar.isNotEmpty)
                        ? curUser.avatar
                        : (curUser?.isAdmin == true
                            ? '/uploads/admin_avatar.jpg'
                            : '/default_avatar.svg');

                    return GestureDetector(
                      onTap: _showAddStoryDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF007AFF).withOpacity(0.5),
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(32),
                                    child: MediaImageView(
                                      url: avatarUrl,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF007AFF),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.cardBg, width: 2),
                                    ),
                                    padding: const EdgeInsets.all(3),
                                    child: const Icon(
                                      CupertinoIcons.plus,
                                      size: 13,
                                      color: CupertinoColors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              tr('Add Story', 'Add Story'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final story = stories[index - 1];
                  return GestureDetector(
                    onTap: () => _openStoryViewer(index - 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: story.isViewed
                                    ? [CupertinoColors.systemGrey4, CupertinoColors.systemGrey4]
                                    : [
                                        const Color(0xFFFF2D55),
                                        const Color(0xFFAF52DE),
                                        const Color(0xFF007AFF),
                                      ],
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBg,
                                shape: BoxShape.circle,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: MediaImageView(
                                  url: story.authorAvatar,
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            story.authorName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            story.city,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF34C759),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Spaces Filter Horizontal Segmented Bar
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterPill('all', tr('ទាំងអស់ (All)', 'All')),
                    const SizedBox(width: 8),
                    _buildFilterPill('space-public-1', tr('កម្ពុជា សាធារណៈ', 'Cambodia Public')),
                    const SizedBox(width: 8),
                    _buildFilterPill('space-family-1', tr('គ្រួសាររុងរឿង', 'Family Circle')),
                    const SizedBox(width: 8),
                    _buildFilterPill('space-team-1', tr('ក្រុមបច្ចេកវិទ្យា', 'Tech Builders')),
                  ],
                ),
              ),
            ),
          ),

          // City Location Filter Chips
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Row(
                      children: [
                        const Icon(CupertinoIcons.location_solid, size: 14, color: Color(0xFF34C759)),
                        const SizedBox(width: 4),
                        Text(
                          '${tr("ទីក្រុង", "City")}:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.secondaryText),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    ...cityFilters.map((city) {
                      final isSelected = selectedCityFilter == city;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: LiquidGlassPill(
                          label: city,
                          isSelected: isSelected,
                          activeColor: const Color(0xFF34C759),
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                          onTap: () => _onCityFilterChanged(city),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

          // Focus Mode Banner (if enabled)
          if (focusMode)
            SliverToBoxAdapter(
              child: LiquidGlassContainer(
                margin: EdgeInsets.symmetric(
                  horizontal: ResponsiveLayout.horizontalPadding(context),
                  vertical: 8,
                ),
                padding: const EdgeInsets.all(14),
                borderRadius: 18,
                tintColor: const Color(0xFF34C759).withValues(alpha: 0.14),
                borderColor: const Color(0xFF34C759).withValues(alpha: 0.45),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.check_mark_circled_solid, color: Color(0xFF34C759)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr(
                          'Focus Mode បើកដំណើរការ៖ បិទ Infinite Scroll និងផ្ដល់ជូនតែ Daily Digest សំខាន់ៗចំនួន ២ ប៉ុណ្ណោះក្នុងថ្ងៃនេះ។',
                          'Focus Mode active: Infinite scroll disabled. Showing 2 curated daily digests.',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF34C759),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Feed Posts or Loading
          if (isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CupertinoActivityIndicator(radius: 16),
              ),
            )
          else if (posts.isEmpty && searchedUsers.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  tr('រកមិនឃើញការបង្ហោះនៅក្នុង Space ឬទីក្រុងនេះទេ', 'No posts found in this Space or City'),
                  style: TextStyle(color: AppTheme.secondaryText, fontSize: 16),
                ),
              ),
            )
          else if (posts.isEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 20))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final post = posts[index];
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: PostCard(
                        post: post,
                        onCommentTap: () => _openCommentsModal(post),
                        onPostDeleted: () => _loadInitialData(),
                        onPostUpdated: () => _loadInitialData(),
                      ),
                    ),
                  );
                },
                childCount: posts.length,
              ),
            ),

          // Bottom padding
          SliverToBoxAdapter(
            child: SizedBox(height: ResponsiveLayout.bottomDockClearance(context)),
          ),
        ],
      ),
    );
          },
        );
      },
    );
  }

  Widget _buildFilterPill(String id, String label) {
    final isSelected = selectedSpaceFilter == id;
    return LiquidGlassPill(
      label: label,
      isSelected: isSelected,
      onTap: () => _onSpaceFilterChanged(id),
    );
  }
}
