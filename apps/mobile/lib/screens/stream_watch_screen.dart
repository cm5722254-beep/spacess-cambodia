import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';

import '../models/post_model.dart';
import '../models/stream_model.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../utils/live_broadcast_helper.dart';
import '../utils/media_picker_helper.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/media_image_view.dart';
import '../widgets/web_video_player.dart';

class StreamWatchScreen extends StatefulWidget {
  const StreamWatchScreen({super.key});

  @override
  State<StreamWatchScreen> createState() => _StreamWatchScreenState();
}

class _StreamWatchScreenState extends State<StreamWatchScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<StreamModel> _streams = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final Set<String> _playingStreamIds = {};
  Timer? _autoRefreshTimer;

  final List<Map<String, String>> _categories = const [
    {'id': 'all', 'km': 'ទាំងអស់', 'en': 'All'},
    {'id': 'live', 'km': 'ផ្សាយផ្ទាល់', 'en': 'Live'},
    {'id': 'trending', 'km': 'ពេញនិយម', 'en': 'Trending'},
    {'id': 'tech', 'km': 'បច្ចេកវិទ្យា', 'en': 'Tech'},
    {'id': 'news', 'km': 'ព័ត៌មាន', 'en': 'News'},
    {'id': 'entertainment', 'km': 'កម្សាន្ត', 'en': 'Entertainment'},
  ];

  @override
  void initState() {
    super.initState();
    _loadStreams();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !_isLoading) {
        _loadStreams(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStreams({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }
    final list = await _api.fetchStreams(category: _selectedCategory);
    if (!mounted) return;
    setState(() {
      _streams = list;
      _isLoading = false;
    });
  }

  void _onCategorySelected(String catId) {
    setState(() {
      _selectedCategory = catId;
      _playingStreamIds.clear();
    });
    _loadStreams();
  }

  void _toggleInlinePlay(StreamModel stream) {
    setState(() {
      if (_playingStreamIds.contains(stream.id)) {
        _playingStreamIds.remove(stream.id);
      } else {
        _playingStreamIds
          ..clear()
          ..add(stream.id);
      }
    });
  }

  void _toggleLike(StreamModel stream) async {
    setState(() {
      if (stream.isLiked) {
        stream.isLiked = false;
        stream.likesCount = (stream.likesCount - 1).clamp(0, 999999);
      } else {
        stream.isLiked = true;
        stream.likesCount += 1;
      }
    });
    await _api.toggleStreamLike(stream.id);
  }

  void _openCommentsSheet(StreamModel stream) {
    final post = PostModel(
      id: stream.id,
      content: stream.title,
      author: Author(
        id: stream.authorId,
        name: stream.authorName,
        username: 'creator',
        avatar: stream.authorAvatar,
        role: stream.authorRole,
        isVerified: stream.authorIsVerified,
      ),
      space: SpaceRef(
        id: 'public',
        name: 'Watch & Live',
        mode: 'PUBLIC',
        color: '#007AFF',
        icon: 'play',
      ),
      circle: 'Public / សាធារណៈ',
      city: 'Phnom Penh, Cambodia',
      timeAgo: tr('ថ្មីៗនេះ', 'Just now'),
      likeCount: stream.likesCount,
      commentCount: stream.commentsCount,
      shareCount: 0,
      isLiked: stream.isLiked,
      isBookmarked: false,
      videoUrl: stream.videoUrl,
      tags: const [],
      comments: const [],
    );

    showCupertinoModalPopup(
      context: context,
      builder: (_) => CommentsSheet(post: post),
    );
  }

  Future<void> _deleteStream(StreamModel stream) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(tr('លុបវីដេអូ / Live នេះ?', 'Delete Video / Stream?')),
        content: Text(tr(
          'សកម្មភាពនេះមិនអាចត្រឡប់វិញបានទេ។',
          'This action cannot be undone.',
        )),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('បោះបង់', 'Cancel')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('លុបចោល', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await _api.deleteStream(stream.id);
      if (ok) {
        await _loadStreams();
      }
    }
  }

  void _shareStream(StreamModel stream) {
    final url = 'https://spaces-cambodia.vercel.app/watch/${stream.id}';
    Clipboard.setData(ClipboardData(text: url));
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(tr('បានចម្លងតំណភ្ជាប់', 'Link Copied')),
        content: Text('${stream.title}\n\n$url'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('យល់ព្រម', 'OK')),
          ),
        ],
      ),
    );
  }

  void _openWatchModal(StreamModel stream) {
    setState(() => _playingStreamIds.remove(stream.id));
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => _WatchStreamModal(
          stream: stream,
          onChanged: () => _loadStreams(silent: true),
        ),
      ),
    );
  }

  void _openGoLiveSetupSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'entertainment';
    String facingMode = 'user';
    bool isStarting = false;
    String? errorMsg;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final cats = _categories.where((c) => c['id'] != 'all' && c['id'] != 'live').toList();
          return LiquidGlassSheet(
            initialHeightFraction: 0.82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: isStarting ? null : () => Navigator.pop(ctx),
                      child: Text(tr('បោះបង់', 'Cancel')),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.dot_radiowaves_left_right,
                            color: Color(0xFFFF2D55),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              tr('បើក Live ផ្ទាល់តាមកាមេរ៉ា', 'Go Live with Camera'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      LiquidGlassContainer(
                        borderRadius: 16,
                        padding: const EdgeInsets.all(12),
                        tintColor: const Color(0xFFFF2D55).withValues(alpha: 0.12),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.videocam_circle_fill, color: Color(0xFFFF2D55), size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tr(
                                  'ប្រើកាមេរ៉ា និងមីក្រូហ្វូនពិតប្រាកដ ផ្សាយផ្ទាល់ភ្លាមៗ និងរក្សាទុកជាវីដេអូ Replay ក្រោយចប់។',
                                  'Streams live from your real camera & mic, then saves a full VOD replay automatically when finished.',
                                ),
                                style: TextStyle(fontSize: 12, color: AppTheme.primaryText, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        tr('ចំណងជើងការផ្សាយផ្ទាល់', 'Live Stream Title'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                      ),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: titleCtrl,
                        placeholder: tr('ឧ. និយាយលេងពេលល្ងាចនៅភ្នំពេញ...', 'e.g. Evening hangout in Phnom Penh...'),
                        padding: const EdgeInsets.all(13),
                        style: TextStyle(color: AppTheme.primaryText, fontSize: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.fieldBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border, width: 0.7),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr('ការពិពណ៌នា (ស្រេចចិត្ត)', 'Description (Optional)'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                      ),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: descCtrl,
                        maxLines: 2,
                        placeholder: tr('សរសេរអំពីការផ្សាយផ្ទាល់របស់អ្នក...', 'Tell viewers what your live is about...'),
                        padding: const EdgeInsets.all(13),
                        style: TextStyle(color: AppTheme.primaryText, fontSize: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.fieldBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border, width: 0.7),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        tr('ប្រភេទមាតិកា', 'Category'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: cats.map((c) {
                          final id = c['id']!;
                          final label = LanguageService().isKhmer ? c['km']! : c['en']!;
                          return LiquidGlassPill(
                            label: label,
                            isSelected: category == id,
                            onTap: () => setSheetState(() => category = id),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr('ជ្រើសរើសកាមេរ៉ាដំបូង', 'Initial Camera'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                      ),
                      const SizedBox(height: 8),
                      LiquidGlassSegmentControl<String>(
                        groupValue: facingMode,
                        items: [
                          LiquidGlassSegmentItem(
                            value: 'user',
                            label: tr('កាមេរ៉ាមុខ', 'Front Camera'),
                            icon: CupertinoIcons.person_crop_circle,
                          ),
                          LiquidGlassSegmentItem(
                            value: 'environment',
                            label: tr('កាមេរ៉ាក្រោយ', 'Rear Camera'),
                            icon: CupertinoIcons.camera_viewfinder,
                          ),
                        ],
                        onValueChanged: (val) => setSheetState(() => facingMode = val),
                      ),
                      if (errorMsg != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMsg!,
                          style: const TextStyle(
                            color: Color(0xFFFF3B30),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      LiquidGlassButton(
                        label: tr('ចាប់ផ្តើម Live ឥឡូវនេះ', 'Start Live Camera'),
                        icon: CupertinoIcons.dot_radiowaves_left_right,
                        variant: LiquidButtonVariant.danger,
                        expand: true,
                        isLoading: isStarting,
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) {
                            setSheetState(() {
                              errorMsg = tr(
                                'សូមបញ្ចូលចំណងជើងមុនពេលចាប់ផ្តើម Live។',
                                'Please enter a title before starting Live.',
                              );
                            });
                            return;
                          }
                          setSheetState(() {
                            isStarting = true;
                            errorMsg = null;
                          });
                          final created = await _api.createStream(
                            title: title,
                            description: descCtrl.text.trim(),
                            videoUrl: '',
                            category: category,
                            duration: 'LIVE',
                            isLive: true,
                          );
                          if (!ctx.mounted) return;
                          if (created == null) {
                            setSheetState(() {
                              isStarting = false;
                              errorMsg = tr(
                                'មិនអាចបង្កើត Live Stream បានទេ សូមសាកល្បងម្ដងទៀត។',
                                'Could not create live stream session. Please try again.',
                              );
                            });
                            return;
                          }
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          Navigator.of(context, rootNavigator: true).push(
                            CupertinoPageRoute(
                              fullscreenDialog: true,
                              builder: (_) => _GoLiveCameraModal(
                                stream: created,
                                initialFacingMode: facingMode,
                                onEnded: () => _loadStreams(),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openCreateStreamSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final videoUrlCtrl = TextEditingController();
    String category = 'trending';
    bool isLive = false;
    bool isUploading = false;
    bool isSubmitting = false;
    String? errorMsg;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final cats = _categories.where((c) => c['id'] != 'all' && c['id'] != 'live').toList();
          return LiquidGlassSheet(
            initialHeightFraction: 0.88,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                      child: Text(tr('បោះបង់', 'Cancel')),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          tr('បង្ហោះវីដេអូ Watch', 'Upload Watch Video'),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      LiquidGlassButton(
                        label: isUploading
                            ? tr('កំពុងផ្ទុកវីដេអូទៅ Storage...', 'Uploading video to storage...')
                            : tr('ជ្រើសរើសវីដេអូពីទូរស័ព្ទ / ឧបករណ៍', 'Pick Video from Phone Gallery'),
                        icon: CupertinoIcons.videocam_fill,
                        variant: LiquidButtonVariant.subtle,
                        expand: true,
                        isLoading: isUploading,
                        onPressed: () async {
                          setSheetState(() {
                            isUploading = true;
                            errorMsg = null;
                          });
                          final uploadedUrl = await MediaPickerHelper.pickAndUploadMedia(accept: 'video/*');
                          if (!ctx.mounted) return;
                          setSheetState(() {
                            isUploading = false;
                            if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                              videoUrlCtrl.text = uploadedUrl;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr('ឬ តំណភ្ជាប់វីដេអូ (Video URL)', 'Or Video URL'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                      ),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: videoUrlCtrl,
                        placeholder: tr('តំណភ្ជាប់វីដេអូ ឬជ្រើសពីទូរស័ព្ទខាងលើ...', 'Video URL or pick above...'),
                        padding: const EdgeInsets.all(12),
                        style: TextStyle(color: AppTheme.primaryText),
                        decoration: BoxDecoration(
                          color: AppTheme.fieldBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border, width: 0.7),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        tr('ចំណងជើងវីដេអូ', 'Video Title'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                      ),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: titleCtrl,
                        placeholder: tr('បញ្ចូលចំណងជើងវីដេអូ...', 'Enter video title...'),
                        padding: const EdgeInsets.all(12),
                        style: TextStyle(color: AppTheme.primaryText),
                        decoration: BoxDecoration(
                          color: AppTheme.fieldBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border, width: 0.7),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        tr('ការពិពណ៌នាលម្អិត', 'Description'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                      ),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: descCtrl,
                        placeholder: tr('រៀបរាប់អំពីខ្លឹមសារវីដេអូ...', 'Describe video content...'),
                        maxLines: 3,
                        padding: const EdgeInsets.all(12),
                        style: TextStyle(color: AppTheme.primaryText),
                        decoration: BoxDecoration(
                          color: AppTheme.fieldBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border, width: 0.7),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        tr('ប្រភេទវីដេអូ', 'Category'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: cats.map((c) {
                          final id = c['id']!;
                          final label = LanguageService().isKhmer ? c['km']! : c['en']!;
                          return LiquidGlassPill(
                            label: label,
                            isSelected: category == id,
                            onTap: () => setSheetState(() => category = id),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      LiquidGlassContainer(
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.dot_radiowaves_left_right,
                                    color: Color(0xFFFF2D55),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      tr('សម្គាល់ជា Live Stream', 'Mark as Live Stream'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryText,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CupertinoSwitch(
                              value: isLive,
                              onChanged: (val) => setSheetState(() => isLive = val),
                            ),
                          ],
                        ),
                      ),
                      if (errorMsg != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorMsg!,
                          style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 20),
                      LiquidGlassButton(
                        label: tr('បង្ហោះវីដេអូឥឡូវនេះ', 'Publish Video Now'),
                        icon: CupertinoIcons.arrow_up_circle_fill,
                        expand: true,
                        isLoading: isSubmitting,
                        onPressed: () async {
                          final vUrl = videoUrlCtrl.text.trim();
                          final title = titleCtrl.text.trim();
                          if (vUrl.isEmpty || title.isEmpty) {
                            setSheetState(() {
                              errorMsg = tr(
                                'សូមជ្រើសរើសវីដេអូ និងបញ្ចូលចំណងជើងជាមុនសិន។',
                                'Please provide a video and a title first.',
                              );
                            });
                            return;
                          }
                          setSheetState(() => isSubmitting = true);
                          await _api.createStream(
                            title: title,
                            description: descCtrl.text.trim(),
                            videoUrl: vUrl,
                            category: category,
                            isLive: isLive,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadStreams();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<StreamModel> get _filteredStreams {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _streams;
    return _streams.where((s) {
      return s.title.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q) ||
          s.authorName.toLowerCase().contains(q);
    }).toList();
  }

  bool _looksLikeImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    if (lower.startsWith('data:image/')) return true;
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _api.isDarkModeNotifier,
      builder: (context, _, __) {
        return ValueListenableBuilder<String>(
          valueListenable: LanguageService().languageNotifier,
          builder: (context, __, ___) {
            final compact = ResponsiveLayout.isCompact(context);
            final hPad = ResponsiveLayout.horizontalPadding(context);
            final visibleStreams = _filteredStreams;

            return CupertinoPageScaffold(
              backgroundColor: AppTheme.scaffoldBg,
              child: LiquidGlassAmbientBackground(
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Liquid Glass Header Bar
                      Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 8),
                        child: LiquidGlassContainer(
                          borderRadius: 24,
                          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.play_rectangle_fill,
                                color: Color(0xFFFF2D55),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tr('Watch & Live', 'Watch & Live'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.primaryText,
                                    fontWeight: FontWeight.w800,
                                    fontSize: compact ? 15 : 17,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              LiquidGlassButton(
                                label: compact ? tr('Live', 'Live') : tr('បើក Live', 'Go Live'),
                                icon: CupertinoIcons.dot_radiowaves_left_right,
                                variant: LiquidButtonVariant.danger,
                                borderRadius: 16,
                                fontSize: 12,
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 10 : 12,
                                  vertical: 7,
                                ),
                                onPressed: _openGoLiveSetupSheet,
                              ),
                              const SizedBox(width: 6),
                              LiquidGlassButton(
                                label: compact ? '' : tr('បង្ហោះ', 'Post'),
                                icon: CupertinoIcons.plus,
                                variant: LiquidButtonVariant.primary,
                                borderRadius: 16,
                                fontSize: 12,
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 9 : 11,
                                  vertical: 7,
                                ),
                                onPressed: _openCreateStreamSheet,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Search Field
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        child: CupertinoSearchTextField(
                          controller: _searchCtrl,
                          placeholder: tr('ស្វែងរកវីដេអូ ឬ Live...', 'Search videos or live streams...'),
                          backgroundColor: AppTheme.glassPillBg,
                          style: TextStyle(color: AppTheme.primaryText, fontSize: 14),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),

                      // Categories Strip
                      SizedBox(
                        height: 52,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final cat = _categories[idx];
                            final id = cat['id']!;
                            final label = LanguageService().isKhmer ? cat['km']! : cat['en']!;
                            return LiquidGlassPill(
                              label: label,
                              icon: id == 'live' ? CupertinoIcons.dot_radiowaves_left_right : null,
                              activeColor: id == 'live' ? const Color(0xFFFF2D55) : null,
                              isSelected: _selectedCategory == id,
                              onTap: () => _onCategorySelected(id),
                            );
                          },
                        ),
                      ),

                      // Stream List
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CupertinoActivityIndicator(radius: 14))
                            : visibleStreams.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: hPad * 2),
                                      child: LiquidGlassContainer(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              CupertinoIcons.play_rectangle,
                                              size: 46,
                                              color: CupertinoColors.systemGrey,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              tr(
                                                'មិនទាន់មានវីដេអូ ឬការផ្សាយផ្ទាល់នៅឡើយទេ',
                                                'No live streams or videos in this category yet.',
                                              ),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                                            ),
                                            const SizedBox(height: 14),
                                            LiquidGlassButton(
                                              label: tr('បើក Live ផ្ទាល់ដំបូង', 'Start First Live'),
                                              icon: CupertinoIcons.dot_radiowaves_left_right,
                                              variant: LiquidButtonVariant.danger,
                                              onPressed: _openGoLiveSetupSheet,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : CustomScrollView(
                                    physics: const BouncingScrollPhysics(
                                      parent: AlwaysScrollableScrollPhysics(),
                                    ),
                                    slivers: [
                                      CupertinoSliverRefreshControl(
                                        onRefresh: () => _loadStreams(),
                                      ),
                                      SliverPadding(
                                        padding: EdgeInsets.fromLTRB(
                                          hPad,
                                          4,
                                          hPad,
                                          ResponsiveLayout.bottomDockClearance(context),
                                        ),
                                        sliver: SliverList.separated(
                                          itemCount: visibleStreams.length,
                                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                                          itemBuilder: (context, idx) => _buildStreamCard(visibleStreams[idx]),
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStreamCard(StreamModel stream) {
    final isPlaying = _playingStreamIds.contains(stream.id);
    final currentUser = _api.currentUser;
    final canDelete = currentUser != null && (currentUser.id == stream.authorId || currentUser.isAdmin);
    final thumbUrl = _looksLikeImageUrl(stream.thumbnailUrl)
        ? stream.thumbnailUrl!
        : (_looksLikeImageUrl(stream.videoUrl) ? stream.videoUrl : '');

    return LiquidGlassContainer(
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 16:9 Viewport
          GestureDetector(
            onTap: () => stream.isLive ? _openWatchModal(stream) : _toggleInlinePlay(stream),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: const Color(0xFF090D16),
                      child: isPlaying
                          ? (stream.isLive
                              ? _LiveChunkPlayerView(streamId: stream.id, initialPoster: stream.thumbnailUrl)
                              : WebVideoPlayerWidget(
                                  videoUrl: stream.videoUrl,
                                  autoPlay: true,
                                  isLooping: true,
                                  showControls: true,
                                  fit: BoxFit.contain,
                                ))
                          : (thumbUrl.isNotEmpty
                              ? MediaImageView(url: thumbUrl, fit: BoxFit.cover)
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: stream.isLive
                                          ? const [Color(0xFF280B1A), Color(0xFF0A1224)]
                                          : const [Color(0xFF10192D), Color(0xFF090D16)],
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      stream.isLive
                                          ? CupertinoIcons.dot_radiowaves_left_right
                                          : CupertinoIcons.film,
                                      color: Colors.white.withValues(alpha: 0.25),
                                      size: 54,
                                    ),
                                  ),
                                )),
                    ),
                  ),

                  // Live / VOD Badge
                  if (stream.isLive)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF2D55), Color(0xFFFF3B30)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: CupertinoColors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                            if (stream.viewerCount != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${stream.viewerCount} ${tr("នាក់", "watching")}',
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  else
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xB8000000),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          stream.duration,
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                  // Fullscreen Watch Pill
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: LiquidGlassPressable(
                      onTap: () => _openWatchModal(stream),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xB3000000),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.arrow_up_left_arrow_down_right,
                              color: CupertinoColors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              stream.isLive
                                  ? tr('ចូលមើល Live', 'Join Live')
                                  : tr('មើលពេញ & Comment', 'Fullscreen'),
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Center Play Button
                  if (!isPlaying)
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0x99000000),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 1.5),
                      ),
                      child: const Icon(
                        CupertinoIcons.play_fill,
                        color: CupertinoColors.white,
                        size: 26,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Stream Metadata & Actions
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: MediaImageView(
                        url: stream.authorAvatar,
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
                          Text(
                            stream.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryText,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                              Text(
                                stream.authorName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.secondaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (stream.authorIsVerified)
                                const Icon(
                                  CupertinoIcons.checkmark_seal_fill,
                                  color: Color(0xFF007AFF),
                                  size: 13,
                                ),
                              Text(
                                '• ${stream.viewsCount} ${tr("ដង", "views")}',
                                style: TextStyle(fontSize: 11, color: AppTheme.tertiaryText),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (canDelete)
                      CupertinoButton(
                        padding: const EdgeInsets.all(6),
                        minSize: 28,
                        onPressed: () => _deleteStream(stream),
                        child: const Icon(
                          CupertinoIcons.trash,
                          size: 17,
                          color: Color(0xFFFF3B30),
                        ),
                      ),
                  ],
                ),
                if (stream.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    stream.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: AppTheme.secondaryText, height: 1.35),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    LiquidGlassPressable(
                      onTap: () => _toggleLike(stream),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              stream.isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                              size: 18,
                              color: stream.isLiked ? const Color(0xFFFF2D55) : AppTheme.secondaryText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${stream.likesCount}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: stream.isLiked ? const Color(0xFFFF2D55) : AppTheme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    LiquidGlassPressable(
                      onTap: () => stream.isLive ? _openWatchModal(stream) : _openCommentsSheet(stream),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.chat_bubble_2, size: 18, color: AppTheme.secondaryText),
                            const SizedBox(width: 6),
                            Text(
                              '${stream.commentsCount}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    LiquidGlassPressable(
                      onTap: () => _shareStream(stream),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.share, size: 18, color: AppTheme.secondaryText),
                            const SizedBox(width: 6),
                            Text(
                              tr('ចែករំលែក', 'Share'),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Broadcaster fullscreen camera modal with real getUserMedia capture, flip/mute, live viewer & comment overlay, and VOD replay saving.
class _GoLiveCameraModal extends StatefulWidget {
  final StreamModel stream;
  final String initialFacingMode;
  final VoidCallback onEnded;

  const _GoLiveCameraModal({
    required this.stream,
    required this.initialFacingMode,
    required this.onEnded,
  });

  @override
  State<_GoLiveCameraModal> createState() => _GoLiveCameraModalState();
}

class _GoLiveCameraModalState extends State<_GoLiveCameraModal> {
  final ApiService _api = ApiService();
  final TextEditingController _commentCtrl = TextEditingController();

  late String _previewViewId;
  late String _facingMode;
  bool _isMuted = false;
  bool _cameraReady = false;
  bool _isStopping = false;
  bool _hasStopped = false;
  String? _cameraError;
  int _elapsedSeconds = 0;
  int _viewerCount = 1;
  int _likesCount = 0;
  int _chunkSeq = 0;
  List<Map<String, dynamic>> _liveComments = [];

  Timer? _clockTimer;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _facingMode = widget.initialFacingMode;
    _previewViewId = LiveBroadcastHelper.ensurePreviewViewRegistered();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startBroadcast());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _cameraReady && !_isStopping) {
        setState(() => _elapsedSeconds += 1);
      }
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollLiveRoom());
  }

  Future<void> _startBroadcast() async {
    setState(() {
      _cameraReady = false;
      _cameraError = null;
    });
    final ok = await LiveBroadcastHelper.startCameraBroadcast(
      streamId: widget.stream.id,
      facingMode: _facingMode,
      onChunkUploaded: (seq, viewers) {
        if (!mounted) return;
        setState(() {
          _chunkSeq = seq;
          if (viewers > _viewerCount) _viewerCount = viewers;
        });
      },
      onCameraFlipped: (mode) {
        if (mounted) setState(() => _facingMode = mode);
      },
      onMicToggled: (muted) {
        if (mounted) setState(() => _isMuted = muted);
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _cameraError = err == 'NotAllowedError'
              ? tr(
                  'សូមអនុញ្ញាតឱ្យ Browser ប្រើកាមេរ៉ា និងមីក្រូហ្វូន (Camera & Mic Permission)។',
                  'Please grant Camera & Microphone permission in your browser settings.',
                )
              : tr(
                  'មិនអាចបើកកាមេរ៉ាបានទេ ($err)។ ត្រូវការ HTTPS និងកាមេរ៉ាលើឧបករណ៍។',
                  'Could not access camera ($err). HTTPS and a device camera are required.',
                );
        });
      },
    );
    if (mounted && ok) {
      setState(() => _cameraReady = true);
    }
  }

  Future<void> _pollLiveRoom() async {
    if (!mounted || _hasStopped) return;
    final state = await _api.fetchLiveStreamState(widget.stream.id);
    if (!mounted || state == null) return;
    final rawComments = (state['comments'] as List?) ?? [];
    setState(() {
      _viewerCount = (state['viewerCount'] as num?)?.toInt() ?? _viewerCount;
      _likesCount = (state['likesCount'] as num?)?.toInt() ?? _likesCount;
      _liveComments = rawComments
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    });
  }

  Future<void> _sendHostComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    _commentCtrl.clear();
    final created = await _api.addStreamComment(widget.stream.id, text);
    if (mounted && created != null) {
      setState(() {
        _liveComments = [..._liveComments, created];
      });
    }
  }

  Future<void> _finishBroadcast({bool popAfter = true}) async {
    if (_isStopping || _hasStopped) {
      if (popAfter && mounted) Navigator.pop(context);
      return;
    }
    setState(() => _isStopping = true);
    await LiveBroadcastHelper.stopBroadcast();
    _hasStopped = true;
    widget.onEnded();
    if (popAfter && mounted) {
      Navigator.pop(context);
    }
  }

  String _formatClock(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pollTimer?.cancel();
    _commentCtrl.dispose();
    if (!_hasStopped) {
      LiveBroadcastHelper.stopBroadcast();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF05070B),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Real Browser Camera Preview
          if (kIsWeb)
            HtmlElementView(viewType: _previewViewId)
          else
            const Center(
              child: Text(
                'Web Camera Broadcast only',
                style: TextStyle(color: CupertinoColors.white),
              ),
            ),

          // Top & Bottom Scrim
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.62),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.78),
                  ],
                  stops: const [0.0, 0.24, 0.56, 1.0],
                ),
              ),
            ),
          ),

          // Status Overlay (connecting / error)
          if (!_cameraReady && _cameraError == null)
            Center(
              child: LiquidGlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                tintColor: const Color(0xCC0D1322),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupertinoActivityIndicator(color: CupertinoColors.white, radius: 14),
                    const SizedBox(height: 10),
                    Text(
                      tr('កំពុងបើកកាមេរ៉ា និងមីក្រូហ្វូន...', 'Opening camera & microphone...'),
                      style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          if (_cameraError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LiquidGlassContainer(
                  padding: const EdgeInsets.all(20),
                  tintColor: const Color(0xE6141926),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        color: Color(0xFFFF9F0A),
                        size: 38,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _cameraError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: CupertinoColors.white, fontSize: 13.5, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: LiquidGlassButton(
                              label: tr('បិទ', 'Close'),
                              variant: LiquidButtonVariant.neutral,
                              onPressed: () => _finishBroadcast(popAfter: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: LiquidGlassButton(
                              label: tr('សាកល្បងម្ដងទៀត', 'Retry'),
                              variant: LiquidButtonVariant.primary,
                              onPressed: _startBroadcast,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Live HUD Controls
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 12 + viewInsets),
              child: Column(
                children: [
                  // Top Bar
                  Row(
                    children: [
                      LiquidGlassContainer(
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        tintColor: const Color(0xCCFF2D55),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: CupertinoColors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'LIVE • ${_formatClock(_elapsedSeconds)}',
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      LiquidGlassContainer(
                        borderRadius: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        tintColor: const Color(0x88000000),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.eye_fill, color: CupertinoColors.white, size: 13),
                            const SizedBox(width: 5),
                            Text(
                              '$_viewerCount',
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(CupertinoIcons.heart_fill, color: Color(0xFFFF2D55), size: 13),
                            const SizedBox(width: 4),
                            Text(
                              '$_likesCount',
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      LiquidGlassPressable(
                        onTap: () => LiveBroadcastHelper.flipCamera(),
                        child: LiquidGlassContainer(
                          borderRadius: 20,
                          padding: const EdgeInsets.all(9),
                          tintColor: const Color(0x88000000),
                          child: const Icon(
                            CupertinoIcons.camera_rotate_fill,
                            color: CupertinoColors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      LiquidGlassPressable(
                        onTap: () => LiveBroadcastHelper.toggleMute(),
                        child: LiquidGlassContainer(
                          borderRadius: 20,
                          padding: const EdgeInsets.all(9),
                          tintColor: _isMuted ? const Color(0xCCFF3B30) : const Color(0x88000000),
                          child: Icon(
                            _isMuted ? CupertinoIcons.mic_slash_fill : CupertinoIcons.mic_fill,
                            color: CupertinoColors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_chunkSeq > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${widget.stream.title} • Stream #$_chunkSeq',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Live Comments Overlay (latest 5)
                  if (_liveComments.isNotEmpty)
                    SizedBox(
                      height: 150,
                      child: ListView.separated(
                        reverse: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _liveComments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, idx) {
                          final c = _liveComments[_liveComments.length - 1 - idx];
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: LiquidGlassContainer(
                              borderRadius: 16,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              tintColor: const Color(0x990C111E),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: MediaImageView(
                                      url: c['avatar']?.toString() ?? '/default_avatar.svg',
                                      width: 22,
                                      height: 22,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${c['author'] ?? 'User'}: ',
                                            style: const TextStyle(
                                              color: Color(0xFF64D2FF),
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          TextSpan(
                                            text: c['text']?.toString() ?? '',
                                            style: const TextStyle(
                                              color: CupertinoColors.white,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
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

                  // Bottom Host Composer + End Live Action
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: _commentCtrl,
                          placeholder: tr('ឆ្លើយតបអ្នកទស្សនា...', 'Say something to viewers...'),
                          placeholderStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                          style: const TextStyle(color: CupertinoColors.white, fontSize: 13.5),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          onSubmitted: (_) => _sendHostComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      LiquidGlassButton(
                        label: _isStopping ? tr('កំពុងរក្សាទុក...', 'Saving...') : tr('បញ្ចប់ Live', 'End Live'),
                        icon: CupertinoIcons.stop_fill,
                        variant: LiquidButtonVariant.danger,
                        borderRadius: 18,
                        fontSize: 12.5,
                        isLoading: _isStopping,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        onPressed: () => _finishBroadcast(popAfter: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dual-buffered HTML5 <video> chunk player for low-latency segmented HTTP Live playback without black-screen flicker.
class _LiveChunkPlayerView extends StatefulWidget {
  final String streamId;
  final String? initialPoster;
  final void Function(int seq, int viewers, int likes)? onMetrics;
  final void Function(List<Map<String, dynamic>> comments)? onComments;
  final void Function(String vodUrl)? onStreamEnded;

  const _LiveChunkPlayerView({
    required this.streamId,
    this.initialPoster,
    this.onMetrics,
    this.onComments,
    this.onStreamEnded,
  });

  @override
  State<_LiveChunkPlayerView> createState() => _LiveChunkPlayerViewState();
}

class _LiveChunkPlayerViewState extends State<_LiveChunkPlayerView> {
  final ApiService _api = ApiService();
  late String _viewId;

  html.VideoElement? _slotA;
  html.VideoElement? _slotB;
  bool _slotAActive = true;
  bool _hasVideoFrame = false;
  bool _isMuted = true;
  bool _isPolling = false;
  int _lastSeq = 0;
  String? _posterUrl;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _posterUrl = widget.initialPoster;
    _viewId = 'live-watch-${widget.streamId}-${DateTime.now().microsecondsSinceEpoch}';
    _registerDomContainer();
    _pollState();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) => _pollState());
  }

  void _registerDomContainer() {
    if (!kIsWeb) return;
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int _) {
      final host = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.position = 'relative'
        ..style.overflow = 'hidden'
        ..style.backgroundColor = '#070B14';

      html.VideoElement buildSlot(double initialOpacity) {
        final v = html.VideoElement()
          ..autoplay = true
          ..muted = _isMuted
          ..controls = false
          ..preload = 'auto'
          ..style.position = 'absolute'
          ..style.top = '0'
          ..style.left = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain'
          ..style.transition = 'opacity 180ms ease'
          ..style.opacity = '$initialOpacity';
        v.setAttribute('playsinline', 'true');
        v.setAttribute('webkit-playsinline', 'true');
        return v;
      }

      _slotA = buildSlot(1);
      _slotB = buildSlot(0);
      host.children
        ..add(_slotA!)
        ..add(_slotB!);
      return host;
    });
  }

  String _normalizeMediaUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('/') ||
        trimmed.startsWith('data:') ||
        trimmed.startsWith('blob:')) {
      return trimmed;
    }
    return '/$trimmed';
  }

  Future<void> _pollState() async {
    if (_isPolling || !mounted) return;
    _isPolling = true;
    try {
      final data = await _api.fetchLiveStreamState(widget.streamId);
      if (!mounted || data == null) return;

      final isLive = data['isLive'] == true;
      final seq = (data['seq'] as num?)?.toInt() ?? 0;
      final chunkUrl = data['chunkUrl']?.toString() ?? '';
      final vodUrl = data['videoUrl']?.toString() ?? '';
      final poster = data['posterUrl']?.toString();
      final viewers = (data['viewerCount'] as num?)?.toInt() ?? 1;
      final likes = (data['likesCount'] as num?)?.toInt() ?? 0;
      final rawComments = (data['comments'] as List?) ?? [];

      if (poster != null && poster.isNotEmpty && poster != _posterUrl) {
        setState(() => _posterUrl = poster);
      }

      widget.onMetrics?.call(seq, viewers, likes);
      if (rawComments.isNotEmpty) {
        widget.onComments?.call(
          rawComments.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        );
      }

      if (!isLive && vodUrl.isNotEmpty) {
        _pollTimer?.cancel();
        widget.onStreamEnded?.call(vodUrl);
        return;
      }

      if (seq > _lastSeq && chunkUrl.isNotEmpty) {
        _lastSeq = seq;
        _enqueueNextSegment(_normalizeMediaUrl(chunkUrl));
      }
    } finally {
      _isPolling = false;
    }
  }

  void _enqueueNextSegment(String url) {
    if (!kIsWeb || _slotA == null || _slotB == null || url.isEmpty) return;
    final incoming = _slotAActive ? _slotB! : _slotA!;
    final outgoing = _slotAActive ? _slotA! : _slotB!;

    StreamSubscription<html.Event>? sub;
    var switched = false;

    void activateIncoming() {
      if (switched || !mounted) return;
      switched = true;
      sub?.cancel();
      incoming.muted = _isMuted;
      incoming.play().catchError((_) {
        if (mounted && !_isMuted) {
          setState(() => _isMuted = true);
        }
        incoming.muted = true;
        incoming.play().catchError((_) {});
      });
      incoming.style.opacity = '1';
      outgoing.style.opacity = '0';
      _slotAActive = !_slotAActive;
      if (!_hasVideoFrame && mounted) {
        setState(() => _hasVideoFrame = true);
      }
      Future.delayed(const Duration(milliseconds: 220), () {
        try {
          outgoing.pause();
        } catch (_) {}
      });
    }

    sub = incoming.onCanPlay.listen((_) => activateIncoming());
    Future.delayed(const Duration(milliseconds: 850), activateIncoming);
    incoming.src = url;
    incoming.load();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    if (_slotA != null) _slotA!.muted = _isMuted;
    if (_slotB != null) _slotB!.muted = _isMuted;
    final active = _slotAActive ? _slotA : _slotB;
    active?.play().catchError((_) {});
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    try {
      _slotA?.pause();
      _slotA?.src = '';
      _slotB?.pause();
      _slotB?.src = '';
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (kIsWeb)
          HtmlElementView(viewType: _viewId)
        else
          const SizedBox.shrink(),
        if (!_hasVideoFrame && _posterUrl != null && _posterUrl!.isNotEmpty)
          MediaImageView(url: _posterUrl!, fit: BoxFit.cover),
        if (!_hasVideoFrame)
          Center(
            child: LiquidGlassContainer(
              borderRadius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              tintColor: const Color(0xBB0C1220),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CupertinoActivityIndicator(color: CupertinoColors.white, radius: 9),
                  const SizedBox(width: 8),
                  Text(
                    tr('កំពុងភ្ជាប់វីដេអូ Live...', 'Connecting live video...'),
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          bottom: 10,
          right: 10,
          child: LiquidGlassPressable(
            onTap: _toggleMute,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xB8000000),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.32), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isMuted ? CupertinoIcons.speaker_slash_fill : CupertinoIcons.speaker_2_fill,
                    color: CupertinoColors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isMuted ? tr('បើកសំឡេង', 'Unmute') : tr('មានសំឡេង', 'Sound On'),
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fullscreen Live & VOD Watch Modal with real-time chat/comments, likes, and automatic Live -> VOD replay transition.
class _WatchStreamModal extends StatefulWidget {
  final StreamModel stream;
  final VoidCallback onChanged;

  const _WatchStreamModal({
    required this.stream,
    required this.onChanged,
  });

  @override
  State<_WatchStreamModal> createState() => _WatchStreamModalState();
}

class _WatchStreamModalState extends State<_WatchStreamModal> {
  final ApiService _api = ApiService();
  final TextEditingController _commentCtrl = TextEditingController();

  late bool _isLive;
  late String _videoUrl;
  late int _likesCount;
  late bool _isLiked;
  int _viewerCount = 1;
  bool _isPostingComment = false;
  List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _isLive = widget.stream.isLive;
    _videoUrl = widget.stream.videoUrl;
    _likesCount = widget.stream.likesCount;
    _isLiked = widget.stream.isLiked;
    _viewerCount = widget.stream.viewerCount ?? 1;
    _loadComments();
  }

  Future<void> _loadComments() async {
    final items = await _api.fetchStreamComments(widget.stream.id);
    if (mounted) {
      setState(() => _comments = items);
    }
  }

  Future<void> _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount = (_isLiked ? _likesCount + 1 : _likesCount - 1).clamp(0, 999999);
      widget.stream.isLiked = _isLiked;
      widget.stream.likesCount = _likesCount;
    });
    await _api.toggleStreamLike(widget.stream.id);
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _isPostingComment) return;
    setState(() => _isPostingComment = true);
    _commentCtrl.clear();
    final created = await _api.addStreamComment(widget.stream.id, text);
    if (!mounted) return;
    setState(() {
      _isPostingComment = false;
      if (created != null) {
        _comments = [..._comments, created];
      }
    });
    widget.onChanged();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final hPad = ResponsiveLayout.horizontalPadding(context);
    final screenH = MediaQuery.of(context).size.height;
    final playerHeight = (screenH * 0.36).clamp(210.0, 340.0);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.scaffoldBg,
      child: LiquidGlassAmbientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Video / Live Player Container
              SizedBox(
                height: playerHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFF060912),
                      child: _isLive
                          ? _LiveChunkPlayerView(
                              streamId: widget.stream.id,
                              initialPoster: widget.stream.thumbnailUrl,
                              onMetrics: (_, viewers, likes) {
                                if (!mounted) return;
                                setState(() {
                                  _viewerCount = viewers;
                                  if (likes > _likesCount) _likesCount = likes;
                                });
                              },
                              onComments: (liveList) {
                                if (mounted && liveList.length >= _comments.length) {
                                  setState(() => _comments = liveList);
                                }
                              },
                              onStreamEnded: (vodUrl) {
                                if (!mounted) return;
                                setState(() {
                                  _isLive = false;
                                  _videoUrl = vodUrl;
                                });
                                widget.onChanged();
                              },
                            )
                          : (_videoUrl.isNotEmpty
                              ? WebVideoPlayerWidget(
                                  videoUrl: _videoUrl,
                                  autoPlay: true,
                                  isLooping: false,
                                  showControls: true,
                                  fit: BoxFit.contain,
                                )
                              : Center(
                                  child: Text(
                                    tr('មិនមានឯកសារវីដេអូសម្រាប់ចាក់ទេ', 'No playable video yet.'),
                                    style: const TextStyle(color: CupertinoColors.white),
                                  ),
                                )),
                    ),
                    Positioned(
                      top: 10,
                      left: 12,
                      child: LiquidGlassPressable(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0x99000000),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                          ),
                          child: const Icon(CupertinoIcons.xmark, color: CupertinoColors.white, size: 17),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _isLive ? const Color(0xDDFF2D55) : const Color(0xAA000000),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 0.8),
                        ),
                        child: Text(
                          _isLive
                              ? 'LIVE • $_viewerCount ${tr("នាក់", "watching")}'
                              : tr('ចាក់ឡើងវិញ (Replay)', 'VOD Replay'),
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Author + Like/Share Header Card
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 8),
                child: LiquidGlassContainer(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: MediaImageView(
                              url: widget.stream.authorAvatar,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.stream.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.primaryText,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      widget.stream.authorName,
                                      style: TextStyle(
                                        color: AppTheme.secondaryText,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (widget.stream.authorIsVerified) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        CupertinoIcons.checkmark_seal_fill,
                                        color: Color(0xFF007AFF),
                                        size: 13,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          LiquidGlassButton(
                            label: '$_likesCount',
                            icon: _isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                            variant: _isLiked ? LiquidButtonVariant.danger : LiquidButtonVariant.neutral,
                            borderRadius: 16,
                            fontSize: 12.5,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            onPressed: _toggleLike,
                          ),
                        ],
                      ),
                      if (widget.stream.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.stream.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Comments List Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad + 4, vertical: 2),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.chat_bubble_2_fill, size: 15, color: AppTheme.accentBlue),
                    const SizedBox(width: 6),
                    Text(
                      '${tr("មតិយោបល់", "Comments")} (${_comments.length})',
                      style: TextStyle(
                        color: AppTheme.primaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // Real-Time Comments Feed
              Expanded(
                child: _comments.isEmpty
                    ? Center(
                        child: Text(
                          tr('មិនទាន់មានមតិនៅឡើយទេ ចាប់ផ្តើមសរសេរមុនគេ!', 'No comments yet. Say hello!'),
                          style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 12),
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, idx) {
                          final c = _comments[idx];
                          return LiquidGlassContainer(
                            borderRadius: 16,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: MediaImageView(
                                    url: c['avatar']?.toString() ?? '/default_avatar.svg',
                                    width: 30,
                                    height: 30,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c['author']?.toString() ?? 'Spaces User',
                                        style: TextStyle(
                                          color: AppTheme.primaryText,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        c['text']?.toString() ?? '',
                                        style: TextStyle(
                                          color: AppTheme.primaryText,
                                          fontSize: 13.5,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // Liquid Glass Comment Composer
              LiquidGlassContainer(
                borderRadius: 0,
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  10,
                  hPad,
                  10 + viewInsets + MediaQuery.of(context).padding.bottom,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: _commentCtrl,
                        placeholder: tr('សរសេរមតិយោបល់...', 'Write a comment...'),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        style: TextStyle(color: AppTheme.primaryText, fontSize: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.fieldBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.border, width: 0.7),
                        ),
                        onSubmitted: (_) => _submitComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    LiquidGlassButton(
                      label: '',
                      icon: CupertinoIcons.arrow_up,
                      borderRadius: 20,
                      isLoading: _isPostingComment,
                      padding: const EdgeInsets.all(10),
                      onPressed: _submitComment,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
