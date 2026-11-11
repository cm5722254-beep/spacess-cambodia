import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../utils/media_picker_helper.dart';
import '../utils/voice_recorder_helper.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/media_image_view.dart';
import '../widgets/voice_message_bubble.dart';
import '../widgets/web_video_player.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  Timer? _pollTimer;

  List<ChatConversationModel> _chats = [];
  List<PublicUserModel> _friends = [];
  List<PublicUserModel> _incomingRequests = [];
  List<PublicUserModel> _searchResults = [];

  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isOpeningChat = false;

  @override
  void initState() {
    super.initState();
    _loadAll(showLoader: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && _searchQuery.isEmpty) {
        _loadAll(showLoader: false);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _pollTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll({bool showLoader = false}) async {
    if (showLoader && mounted) {
      setState(() => _isLoading = true);
    }
    final results = await Future.wait([
      ApiService().fetchChats(),
      ApiService().fetchFriendsOverview(),
    ]);
    if (!mounted) return;
    final fetchedChats = results[0] as List<ChatConversationModel>;
    final friendsData = results[1] as Map<String, List<PublicUserModel>>;
    setState(() {
      _chats = fetchedChats;
      _friends = friendsData['friends'] ?? [];
      _incomingRequests = friendsData['incoming'] ?? [];
      _isLoading = false;
    });
  }

  void _onSearchChanged(String val) {
    final q = val.trim();
    setState(() => _searchQuery = q);
    _searchDebounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 280), () async {
      final found = await ApiService().searchUsers(q);
      if (mounted && _searchQuery == q) {
        setState(() {
          _searchResults = found;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _openDirectChatWithUser(String userId, {PublicUserModel? userModel}) async {
    final currentUser = ApiService().currentUser;
    final isMe = currentUser?.id == userId;
    if (isMe) return;

    final isAcceptedFriend = _friends.any((f) => f.id == userId) || (currentUser?.isAdmin == true);
    if (!isAcceptedFriend) {
      final target = userModel ??
          _searchResults.where((u) => u.id == userId).firstOrNull ??
          _incomingRequests.where((u) => u.id == userId).firstOrNull;

      final status = target?.friendStatus ?? 'NONE';

      if (status == 'PENDING_SENT') {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('ត្រូវការការយល់ព្រមធ្វើមិត្ត'),
            content: const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text('សំណើសុំធ្វើមិត្តត្រូវបានផ្ញើរួចហើយ។ សូមរង់ចាំការយល់ព្រម (Confirm) ពីភាគីម្ខាងទៀតសិន ទើបអាចឆាតបាន។'),
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('យល់ព្រម'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
        return;
      } else if (status == 'PENDING_RECEIVED' && target != null) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('ទទួលសំណើមិត្ត'),
            content: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text('${target.name} បានផ្ញើសំណើសុំរាប់អានមិត្តមកអ្នក។ សូមចុចយល់ព្រម (Confirm) ដើម្បីចាប់ផ្តើមជជែកកម្សាន្ត។'),
            ),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ទុកពេលក្រោយ'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _respondFriendReq(target, true);
                  _openDirectChatWithUser(userId, userModel: target);
                },
                child: const Text('យល់ព្រម (Confirm)'),
              ),
            ],
          ),
        );
        return;
      } else {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('ភ្ជាប់ទំនាក់ទំនងមិត្ត'),
            content: const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text('ដើម្បីសុវត្ថិភាពនិងភាពឯកជន អ្នកត្រូវតែស្នើសុំធ្វើជាមិត្ត (Add Friend) និងទទួលបានការយល់ព្រមសិន ទើបអាចបើកការជជែកផ្ទាល់បាន។'),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('បោះបង់'),
              ),
              if (target != null)
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _sendFriendReq(target);
                  },
                  child: const Text('+ ស្នើសុំមិត្ត (Add Friend)'),
                ),
            ],
          ),
        );
        return;
      }
    }

    if (_isOpeningChat) return;
    setState(() => _isOpeningChat = true);
    final chat = await ApiService().getOrCreateDirectChat(userId);
    if (!mounted) return;
    setState(() => _isOpeningChat = false);
    if (chat != null) {
      await Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(builder: (_) => ChatConversationScreen(chat: chat)),
      );
      _loadAll(showLoader: false);
    }
  }

  Future<void> _sendFriendReq(PublicUserModel user) async {
    setState(() => user.friendStatus = 'PENDING_SENT');
    final ok = await ApiService().sendFriendRequest(user.id);
    if (ok) {
      await _loadAll(showLoader: false);
      if (_searchQuery.isNotEmpty) {
        final refreshed = await ApiService().searchUsers(_searchQuery);
        if (mounted) setState(() => _searchResults = refreshed);
      }
    } else if (mounted) {
      setState(() => user.friendStatus = 'NONE');
    }
  }

  Future<void> _respondFriendReq(PublicUserModel user, bool accept) async {
    final reqId = user.friendRequestId;
    if (reqId == null || reqId.isEmpty) return;
    final ok = await ApiService().respondFriendRequest(reqId, accept);
    if (ok) {
      await _loadAll(showLoader: false);
      if (_searchQuery.isNotEmpty) {
        final refreshed = await ApiService().searchUsers(_searchQuery);
        if (mounted) setState(() => _searchResults = refreshed);
      }
    }
  }

  Future<void> _toggleFollowUser(PublicUserModel user) async {
    final prev = user.isFollowing;
    setState(() => user.isFollowing = !prev);
    final res = await ApiService().toggleFollow(user.username);
    if (mounted) {
      setState(() => user.isFollowing = res ?? prev);
    }
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
              navigationBar: CupertinoNavigationBar(
                backgroundColor: AppTheme.navBarBg,
                middle: Text(
                  tr('ការជជែក Messenger', 'Spaces Messenger'),
                  style: TextStyle(color: AppTheme.primaryText, fontWeight: FontWeight.w700),
                ),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _loadAll(showLoader: true),
                  child: const Icon(CupertinoIcons.refresh_circled, size: 22, color: Color(0xFF007AFF)),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Live People & Username Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: CupertinoSearchTextField(
                        controller: _searchCtrl,
                        placeholder: tr(
                          'ស្វែងរកឈ្មោះ ឬ @username (ឧ. សុខ ជាតិ)...',
                          'Search name or @username (e.g. Sok Cheat)...',
                        ),
                        style: TextStyle(color: AppTheme.primaryText, fontSize: 14),
                        backgroundColor: AppTheme.fieldBg,
                        onChanged: _onSearchChanged,
                        onSubmitted: _onSearchChanged,
                        onSuffixTap: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      ),
                    ),

                    Expanded(
                      child: _isLoading
                          ? const Center(child: CupertinoActivityIndicator(radius: 16))
                          : CustomScrollView(
                              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                              slivers: [
                                CupertinoSliverRefreshControl(
                                  onRefresh: () => _loadAll(showLoader: false),
                                ),
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(
                                    ResponsiveLayout.horizontalPadding(context),
                                    4,
                                    ResponsiveLayout.horizontalPadding(context),
                                    ResponsiveLayout.bottomDockClearance(context),
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildListDelegate([
                                      // Search Results Section
                                      if (_searchQuery.isNotEmpty) ...[
                                        _buildSearchSection(),
                                        const SizedBox(height: 16),
                                      ],

                                      // Friend Requests Section (Confirm / Decline)
                                      if (_incomingRequests.isNotEmpty) ...[
                                        _buildSectionTitle(
                                          tr(
                                            'សំណើសុំធ្វើមិត្ត (${_incomingRequests.length})',
                                            'Friend Requests (${_incomingRequests.length})',
                                          ),
                                        ),
                                        ..._incomingRequests.map(_buildIncomingRequestCard),
                                        const SizedBox(height: 12),
                                      ],

                                      // Friends Horizontal Active Bar
                                      if (_friends.isNotEmpty) ...[
                                        _buildSectionTitle(
                                          tr('មិត្តភក្តិរបស់អ្នក (${_friends.length})', 'Friends (${_friends.length})'),
                                        ),
                                        SizedBox(
                                          height: 88,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: _friends.length,
                                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                                            itemBuilder: (ctx, idx) {
                                              final f = _friends[idx];
                                              return GestureDetector(
                                                onTap: () => _openDirectChatWithUser(f.id),
                                                child: SizedBox(
                                                  width: 64,
                                                  child: Column(
                                                    children: [
                                                      Stack(
                                                        children: [
                                                          ClipRRect(
                                                            borderRadius: BorderRadius.circular(27),
                                                            child: MediaImageView(
                                                              url: f.avatar,
                                                              width: 54,
                                                              height: 54,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                          Positioned(
                                                            right: 1,
                                                            bottom: 1,
                                                            child: Container(
                                                              width: 13,
                                                              height: 13,
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFF34C759),
                                                                shape: BoxShape.circle,
                                                                border: Border.all(color: AppTheme.scaffoldBg, width: 2),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 5),
                                                      Text(
                                                        f.name,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: AppTheme.primaryText,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                      ],

                                      // Pinned Spaces AI Smart Assistant Card
                                      _buildAiAssistantCard(),
                                      const SizedBox(height: 16),

                                      // Direct Conversations Header
                                      _buildSectionTitle(
                                        tr('ការសន្ទនាផ្ទាល់ខ្លួន (Chats)', 'Conversations'),
                                      ),

                                      if (_chats.isEmpty)
                                        Container(
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cardBg,
                                            borderRadius: BorderRadius.circular(18),
                                            border: Border.all(color: AppTheme.border, width: 0.8),
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(
                                                CupertinoIcons.chat_bubble_2,
                                                size: 38,
                                                color: AppTheme.tertiaryText,
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                tr(
                                                  'ស្វែងរកឈ្មោះមិត្តភក្តិខាងលើ ដើម្បីចាប់ផ្ដើមផ្ញើសារ សំឡេង ឬរូបភាព!',
                                                  'Search a friend above to start sending messages, voice notes, photos, or videos!',
                                                ),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(color: AppTheme.secondaryText, fontSize: 13, height: 1.4),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        ..._chats.map(_buildChatItem),
                                    ]),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.secondaryText),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.person_2_fill, size: 16, color: Color(0xFF007AFF)),
              const SizedBox(width: 6),
              Text(
                tr('លទ្ធផលស្វែងរកមិត្តភក្តិ (People)', 'People Search Results'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isSearching)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CupertinoActivityIndicator(),
              ),
            )
          else if (_searchResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  tr('រកមិនឃើញគណនីដែលមានឈ្មោះ "$_searchQuery" ទេ', 'No accounts found for "$_searchQuery"'),
                  style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
                ),
              ),
            )
          else
            ..._searchResults.map(_buildUserSearchRow),
        ],
      ),
    );
  }

  Widget _buildUserSearchRow(PublicUserModel u) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.6),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: MediaImageView(url: u.avatar, width: 44, height: 44, fit: BoxFit.cover),
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
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                          ),
                        ),
                        if (u.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(CupertinoIcons.checkmark_seal_fill, size: 14, color: Color(0xFF007AFF)),
                        ],
                      ],
                    ),
                    Text(
                      '@${u.username} • ${u.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppTheme.secondaryText),
                    ),
                  ],
                ),
              ),
              // Quick Chat Button
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minSize: 30,
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(12),
                onPressed: () => _openDirectChatWithUser(u.id, userModel: u),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.chat_bubble_fill, size: 13, color: CupertinoColors.white),
                    const SizedBox(width: 4),
                    Text(
                      tr('ឆាត', 'Chat'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CupertinoColors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Friend Action Button
              Expanded(child: _buildFriendActionButton(u)),
              const SizedBox(width: 8),
              // Follow Toggle Button
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minSize: 30,
                color: u.isFollowing ? AppTheme.cardBg : AppTheme.fieldBg,
                borderRadius: BorderRadius.circular(10),
                onPressed: () => _toggleFollowUser(u),
                child: Text(
                  u.isFollowing ? tr('កំពុង Follow', 'Following') : tr('+ Follow', '+ Follow'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: u.isFollowing ? const Color(0xFF007AFF) : AppTheme.primaryText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFriendActionButton(PublicUserModel u) {
    if (u.friendStatus == 'ACCEPTED') {
      return Container(
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF34C759).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF34C759).withOpacity(0.4), width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.person_crop_circle_badge_checkmark, size: 15, color: Color(0xFF34C759)),
            const SizedBox(width: 5),
            Text(
              tr('មិត្តភក្តិ (Friends)', 'Friends'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF34C759)),
            ),
          ],
        ),
      );
    }

    if (u.friendStatus == 'PENDING_SENT') {
      return Container(
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border, width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.clock_fill, size: 14, color: AppTheme.secondaryText),
            const SizedBox(width: 5),
            Text(
              tr('បានផ្ញើសំណើ (Requested)', 'Request Sent'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.secondaryText),
            ),
          ],
        ),
      );
    }

    if (u.friendStatus == 'PENDING_RECEIVED') {
      return Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 6),
              minSize: 32,
              color: const Color(0xFF34C759),
              borderRadius: BorderRadius.circular(10),
              onPressed: () => _respondFriendReq(u, true),
              child: Text(
                tr('យល់ព្រម (Confirm)', 'Confirm'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CupertinoColors.white),
              ),
            ),
          ),
          const SizedBox(width: 6),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minSize: 32,
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(10),
            onPressed: () => _respondFriendReq(u, false),
            child: const Icon(CupertinoIcons.xmark, size: 14, color: CupertinoColors.destructiveRed),
          ),
        ],
      );
    }

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 6),
      minSize: 32,
      color: const Color(0xFF007AFF).withOpacity(0.14),
      borderRadius: BorderRadius.circular(10),
      onPressed: () => _sendFriendReq(u),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.person_add_solid, size: 15, color: Color(0xFF007AFF)),
          const SizedBox(width: 5),
          Text(
            tr('+ បន្ថែមមិត្ត (Add Friend)', '+ Add Friend'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF007AFF)),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestCard(PublicUserModel u) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.35), width: 0.9),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: MediaImageView(url: u.avatar, width: 46, height: 46, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
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
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                      ),
                    ),
                    if (u.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(CupertinoIcons.checkmark_seal_fill, size: 14, color: Color(0xFF007AFF)),
                    ],
                  ],
                ),
                Text(
                  '@${u.username} • ${tr("ស្នើសុំធ្វើជាមិត្តភក្តិ", "Sent you a friend request")}',
                  style: TextStyle(fontSize: 11, color: AppTheme.secondaryText),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minSize: 32,
            color: const Color(0xFF007AFF),
            borderRadius: BorderRadius.circular(10),
            onPressed: () => _respondFriendReq(u, true),
            child: Text(
              tr('យល់ព្រម', 'Confirm'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CupertinoColors.white),
            ),
          ),
          const SizedBox(width: 6),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            minSize: 32,
            color: AppTheme.surfaceBg,
            borderRadius: BorderRadius.circular(10),
            onPressed: () => _respondFriendReq(u, false),
            child: const Icon(CupertinoIcons.xmark, size: 14, color: CupertinoColors.destructiveRed),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAssistantCard() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(builder: (ctx) => const AiChatScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF007AFF).withOpacity(0.12),
              const Color(0xFFAF52DE).withOpacity(0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.4), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF007AFF), Color(0xFFAF52DE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(CupertinoIcons.sparkles, color: CupertinoColors.white, size: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Spaces AI Assistant',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryText,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFAF52DE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'AI BOT',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: CupertinoColors.white),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(
                      'ជំនួយការឆ្លាតវៃ AI & ពិនិត្យប្រព័ន្ធ System Tool',
                      'AI Smart Assistant & System Diagnostics Tool',
                    ),
                    style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(CupertinoIcons.chevron_right, size: 16, color: CupertinoColors.systemGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(ChatConversationModel chat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () async {
          await Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute(builder: (ctx) => ChatConversationScreen(chat: chat)),
          );
          _loadAll(showLoader: false);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border, width: 0.8),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: MediaImageView(
                      url: chat.avatar,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: chat.isGroup ? const Color(0xFF007AFF) : const Color(0xFF34C759),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.cardBg, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  chat.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryText,
                                  ),
                                ),
                              ),
                              if (chat.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(CupertinoIcons.checkmark_seal_fill, size: 14, color: Color(0xFF007AFF)),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          chat.lastMessageTime,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat.lastMessage.isNotEmpty
                          ? chat.lastMessage
                          : tr('ចាប់ផ្ដើមផ្ញើសារឥឡូវនេះ...', 'Start chatting now...'),
                      style: TextStyle(
                        fontSize: 13,
                        color: chat.unreadCount > 0 ? AppTheme.primaryText : AppTheme.secondaryText,
                        fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (chat.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: const BoxDecoration(
                    color: Color(0xFF007AFF),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${chat.unreadCount}',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dedicated Interactive AI Assistant & System Tool Chat Screen
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  final List<String> _quickPrompts = [
    'ពិនិត្យសុខភាពប្រព័ន្ធ (System Health Check)',
    'របៀបដោះសោ Blue Checkmark',
    'ជំនួយការលក់លើ Marketplace',
    'ការបង្ហោះវីដេអូ Watch & Reels',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'ai',
      'text':
          'សួស្តីបាទ! ខ្ញុំគឺ Spaces AI ជំនួយការឆ្លាតវៃនៃ Spaces Social Media Cambodia។\nខ្ញុំអាចជួយលោកអ្នកត្រួតពិនិត្យប្រព័ន្ធ (System Tool), ណែនាំការទូទាត់ Bakong KHQR, និងមុខងារនានាក្នុង App។\nតើខ្ញុំអាចជួយអ្វីដល់លោកអ្នកបាទ?',
      'time': 'Just now',
    });
  }

  void _sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty) return;

    setState(() {
      _messages.add({
        'role': 'user',
        'text': msg,
        'time': 'Now',
      });
      _isTyping = true;
      _controller.clear();
    });

    _scrollToBottom();

    final res = await ApiService().askAi(msg);
    if (mounted) {
      setState(() {
        _isTyping = false;
        final replyText = res?['reply'] ?? 'សូមអភ័យទោស ប្រព័ន្ធកំពុងដំណើរការ សូមព្យាយាមម្តងទៀត។';
        _messages.add({
          'role': 'ai',
          'text': replyText,
          'time': 'Now',
        });
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.scaffoldBg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppTheme.navBarBg,
        middle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF007AFF), Color(0xFFAF52DE)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.sparkles, color: CupertinoColors.white, size: 14),
            ),
            const SizedBox(width: 8),
            Text(
              'Spaces AI Assistant',
              style: TextStyle(color: AppTheme.primaryText, fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Quick Prompts Row
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _quickPrompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final prompt = _quickPrompts[i];
                  return GestureDetector(
                    onTap: () => _sendMessage(prompt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.3), width: 0.8),
                      ),
                      child: Text(
                        prompt,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF007AFF)),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Messages View
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (ctx, i) {
                  final m = _messages[i];
                  final isMe = m['role'] == 'user';
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF007AFF) : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isMe ? const Color(0xFF007AFF) : AppTheme.border,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        m['text'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: isMe ? CupertinoColors.white : AppTheme.primaryText,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const CupertinoActivityIndicator(radius: 8),
                    const SizedBox(width: 8),
                    Text(
                      tr('Spaces AI កំពុងវិភាគ និងឆ្លើយតប...', 'Spaces AI is typing...'),
                      style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                    ),
                  ],
                ),
              ),

            // Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _controller,
                      placeholder: tr('សួរអ្វីមួយទៅកាន់ Spaces AI...', 'Ask Spaces AI anything...'),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      style: TextStyle(color: AppTheme.primaryText),
                      decoration: BoxDecoration(
                        color: AppTheme.fieldBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border, width: 0.6),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.all(10),
                    color: const Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(20),
                    onPressed: () => _sendMessage(_controller.text),
                    child: const Icon(CupertinoIcons.arrow_up, color: CupertinoColors.white, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatConversationScreen extends StatefulWidget {
  final ChatConversationModel chat;
  final String? initialDraft;

  const ChatConversationScreen({super.key, required this.chat, this.initialDraft});

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSendingMedia = false;
  bool _isRecordingVoice = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialDraft != null && widget.initialDraft!.isNotEmpty) {
      _msgController.text = widget.initialDraft!;
    }
    _loadMessages(scrollBottom: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadMessages(scrollBottom: false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _recordTimer?.cancel();
    if (_isRecordingVoice) {
      VoiceRecorderHelper.cancelRecording();
    }
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool scrollBottom = false}) async {
    final prevLen = _messages.length;
    final fetched = await ApiService().fetchMessages(widget.chat.id);
    if (!mounted) return;
    setState(() {
      _messages = fetched;
      _isLoading = false;
    });
    if (scrollBottom || fetched.length > prevLen) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    final newMsg = await ApiService().sendMessage(widget.chat.id, text, mediaType: 'text');
    if (newMsg != null && mounted) {
      setState(() => _messages.add(newMsg));
      _scrollToBottom();
    }
  }

  Future<void> _pickAndSendMedia() async {
    if (_isSendingMedia) return;
    setState(() => _isSendingMedia = true);
    final url = await MediaPickerHelper.pickAndUploadMedia(accept: 'image/*,video/*');
    if (!mounted) return;
    if (url == null || url.isEmpty) {
      setState(() => _isSendingMedia = false);
      return;
    }

    final lower = url.toLowerCase();
    final isVideo = lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.startsWith('data:video/');

    final newMsg = await ApiService().sendMessage(
      widget.chat.id,
      _msgController.text.trim(),
      mediaUrl: url,
      mediaType: isVideo ? 'video' : 'image',
    );
    if (mounted) {
      setState(() {
        _isSendingMedia = false;
        if (newMsg != null) {
          _messages.add(newMsg);
          _msgController.clear();
        }
      });
      _scrollToBottom();
    }
  }

  Future<void> _startVoiceRecord() async {
    await VoiceRecorderHelper.startRecording(
      onStarted: () {
        if (!mounted) return;
        _recordTimer?.cancel();
        setState(() {
          _isRecordingVoice = true;
          _recordSeconds = 0;
        });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordSeconds++);
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() => _isRecordingVoice = false);
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(tr('មីក្រូហ្វូន (Microphone)', 'Microphone Access')),
            content: Text(
              tr(
                'សូមអនុញ្ញាតឱ្យ Browser ប្រើប្រាស់មីក្រូហ្វូន ដើម្បីថតសារជាសំឡេង ($err)។',
                'Please allow microphone permission in your browser to record voice messages ($err).',
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: Text(tr('យល់ព្រម', 'OK')),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  void _cancelVoiceRecord() {
    _recordTimer?.cancel();
    VoiceRecorderHelper.cancelRecording();
    setState(() {
      _isRecordingVoice = false;
      _recordSeconds = 0;
    });
  }

  Future<void> _stopAndSendVoice() async {
    _recordTimer?.cancel();
    final fallbackDuration = _recordSeconds > 0 ? _recordSeconds : 1;
    setState(() {
      _isRecordingVoice = false;
      _isSendingMedia = true;
    });

    final result = await VoiceRecorderHelper.stopAndGetAudio();
    if (!mounted) return;
    if (result == null || result.dataUrl.isEmpty) {
      setState(() => _isSendingMedia = false);
      return;
    }

    final finalUrl = await ApiService().uploadVoiceDataUrl(result.dataUrl) ?? result.dataUrl;
    final dur = result.durationSec > 0 ? result.durationSec : fallbackDuration;

    final newMsg = await ApiService().sendMessage(
      widget.chat.id,
      '',
      mediaUrl: finalUrl,
      mediaType: 'voice',
      durationSec: dur,
    );

    if (mounted) {
      setState(() {
        _isSendingMedia = false;
        if (newMsg != null) _messages.add(newMsg);
      });
      _scrollToBottom();
    }
  }

  String _formatDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ApiService().isDarkModeNotifier,
      builder: (context, isDark, _) {
        return CupertinoPageScaffold(
          backgroundColor: AppTheme.scaffoldBg,
          navigationBar: CupertinoNavigationBar(
            backgroundColor: AppTheme.navBarBg,
            middle: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: MediaImageView(
                    url: widget.chat.avatar,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.chat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.primaryText, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                if (widget.chat.isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(CupertinoIcons.checkmark_seal_fill, size: 14, color: Color(0xFF007AFF)),
                ],
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: _isLoading
                      ? const Center(child: CupertinoActivityIndicator())
                      : _messages.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(36),
                                      child: MediaImageView(
                                        url: widget.chat.avatar,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      widget.chat.title,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      tr(
                                        'ផ្ញើសារ សំឡេង រូបភាព ឬវីដេអូ ដើម្បីចាប់ផ្ដើមការសន្ទនា!',
                                        'Send text, voice notes, photos, or videos to start chatting!',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                            ),
                ),

                // Uploading indicator
                if (_isSendingMedia)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        const CupertinoActivityIndicator(radius: 8),
                        const SizedBox(width: 8),
                        Text(
                          tr('កំពុងផ្ទុក និងផ្ញើឯកសារ...', 'Uploading & sending media...'),
                          style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                        ),
                      ],
                    ),
                  ),

                // Bottom Composer Bar
                LiquidGlassContainer(
                  borderRadius: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: _isRecordingVoice ? _buildVoiceRecordingBar() : _buildStandardComposerBar(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVoiceRecordingBar() {
    return Row(
      children: [
        CupertinoButton(
          padding: const EdgeInsets.all(8),
          color: AppTheme.surfaceBg,
          borderRadius: BorderRadius.circular(18),
          onPressed: _cancelVoiceRecord,
          child: const Icon(CupertinoIcons.trash_fill, color: CupertinoColors.destructiveRed, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(color: Color(0xFFFF3B30), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  tr('កំពុងថតសំឡេង...', 'Recording voice...'),
                  style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  _formatDuration(_recordSeconds),
                  style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: const EdgeInsets.all(10),
          color: const Color(0xFF007AFF),
          borderRadius: BorderRadius.circular(20),
          onPressed: _stopAndSendVoice,
          child: const Icon(CupertinoIcons.arrow_up, color: CupertinoColors.white, size: 18),
        ),
      ],
    );
  }

  Widget _buildStandardComposerBar() {
    return Row(
      children: [
        // Gallery Photo / Video Pick Button
        CupertinoButton(
          padding: const EdgeInsets.all(8),
          minSize: 36,
          onPressed: _isSendingMedia ? null : _pickAndSendMedia,
          child: const Icon(CupertinoIcons.photo_on_rectangle, color: Color(0xFF007AFF), size: 22),
        ),

        // Voice Note Microphone Button
        CupertinoButton(
          padding: const EdgeInsets.all(8),
          minSize: 36,
          onPressed: _isSendingMedia ? null : _startVoiceRecord,
          child: const Icon(CupertinoIcons.mic_fill, color: Color(0xFF007AFF), size: 21),
        ),
        const SizedBox(width: 4),

        Expanded(
          child: CupertinoTextField(
            controller: _msgController,
            placeholder: tr('ផ្ញើសារ (Aa)...', 'Message...'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            style: TextStyle(color: AppTheme.primaryText),
            maxLines: 4,
            minLines: 1,
            decoration: BoxDecoration(
              color: AppTheme.fieldBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border, width: 0.6),
            ),
            onSubmitted: (_) => _sendText(),
          ),
        ),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: const EdgeInsets.all(10),
          color: const Color(0xFF007AFF),
          borderRadius: BorderRadius.circular(20),
          onPressed: _sendText,
          child: const Icon(CupertinoIcons.arrow_up, color: CupertinoColors.white, size: 18),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg) {
    final bubbleColor = msg.isMe ? const Color(0xFF007AFF) : AppTheme.cardBg;
    final hasMedia = msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isMe) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: MediaImageView(
                url: msg.senderAvatar,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: (hasMedia && msg.mediaType != 'voice' && msg.text.isEmpty) ? 6 : 13,
              vertical: (hasMedia && msg.mediaType != 'voice' && msg.text.isEmpty) ? 6 : 9,
            ),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: msg.isMe ? const Color(0xFF007AFF) : AppTheme.border,
                width: 0.6,
              ),
            ),
            child: Column(
              crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!msg.isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      msg.senderName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                  ),

                if (hasMedia && msg.mediaType == 'voice')
                  VoiceMessageBubble(
                    audioUrl: msg.mediaUrl!,
                    durationSec: msg.durationSec,
                    isMe: msg.isMe,
                  )
                else if (hasMedia && msg.mediaType == 'video')
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 220,
                      height: 260,
                      child: WebVideoPlayerWidget(
                        videoUrl: msg.mediaUrl!,
                        autoPlay: false,
                        isLooping: false,
                        showControls: true,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else if (hasMedia && msg.mediaType == 'image')
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: MediaImageView(
                      url: msg.mediaUrl!,
                      width: 210,
                      fit: BoxFit.cover,
                    ),
                  ),

                if (msg.text.isNotEmpty) ...[
                  if (hasMedia) const SizedBox(height: 6),
                  Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: msg.isMe ? CupertinoColors.white : AppTheme.primaryText,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  msg.timeAgo,
                  style: TextStyle(
                    fontSize: 10,
                    color: msg.isMe ? CupertinoColors.white.withOpacity(0.75) : AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
