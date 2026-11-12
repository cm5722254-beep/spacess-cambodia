import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../models/post_model.dart';
import '../services/api_service.dart';
import '../utils/media_picker_helper.dart';
import 'web_video_player.dart';
import 'location_picker_sheet.dart';

class CreateReelSheet extends StatefulWidget {
  final VoidCallback? onReelCreated;

  const CreateReelSheet({super.key, this.onReelCreated});

  static Future<void> show(BuildContext context, {VoidCallback? onReelCreated}) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CreateReelSheet(onReelCreated: onReelCreated),
    );
  }

  @override
  State<CreateReelSheet> createState() => _CreateReelSheetState();
}

class _CreateReelSheetState extends State<CreateReelSheet> {
  int _step = 0; // 0: Pick/Camera, 1: Edit & Preview, 2: Settings & Publish
  String? _selectedVideoUrl;
  final TextEditingController _captionCtrl = TextEditingController();
  String _audioTitle = 'Original Audio - Spaces Cambodia';
  bool _aiLabelEnabled = false;
  String? _selectedLocation;
  String? _selectedSpaceId;
  String? _selectedGroup;
  String? _partnerLink;
  String? _selectedPlaylist;
  String? _abVariantCaption;
  bool _monetizeTips = false;
  final List<String> _taggedPeople = [];
  bool _shareToStory = true;
  bool _boostReel = false;
  bool _isUploading = false;
  bool _isPublishing = false;
  double _uploadProgress = 0.0;

  // Edit tools state
  String _activeFilter = 'normal'; // 'normal', 'warm', 'cinema', 'neon', 'mono'
  double _videoSpeed = 1.0;
  String? _textOverlay;
  String? _stickerOverlay;

  // Real user-uploaded video posts (ZERO demo or stock clips!)
  List<PostModel> _userPreviousVideos = [];
  bool _isLoadingClips = false;

  @override
  void initState() {
    super.initState();
    _loadMyPreviousVideos();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickVideoFromDevice();
    });
  }

  Future<void> _loadMyPreviousVideos() async {
    final userId = ApiService().currentUser?.id;
    if (userId == null) return;
    setState(() => _isLoadingClips = true);
    final posts = await ApiService().fetchFeed(authorId: userId);
    if (!mounted) return;
    setState(() {
      _userPreviousVideos = posts
          .where((p) => p.isReel || (p.videoUrl != null && p.videoUrl!.isNotEmpty))
          .toList();
      _isLoadingClips = false;
    });
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVideoFromDevice({bool captureCamera = false}) async {
    if (_isUploading) return;
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.05;
    });

    try {
      final liveUrl = await MediaPickerHelper.pickAndUploadMedia(
        accept: 'video/*',
        captureCamera: captureCamera,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );

      if (mounted) {
        setState(() => _isUploading = false);
        if (liveUrl != null && liveUrl.isNotEmpty) {
          setState(() {
            _selectedVideoUrl = liveUrl;
            _step = 1; // Move to Step 2: Edit & Preview
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _publishReel() async {
    if (_isPublishing) return;
    if (_selectedVideoUrl == null || _selectedVideoUrl!.isEmpty) return;
    setState(() {
      _isPublishing = true;
      _uploadProgress = 0.25;
    });

    try {
      String finalCaption = _captionCtrl.text.trim();
      if (_textOverlay != null && _textOverlay!.isNotEmpty && !finalCaption.contains(_textOverlay!)) {
        finalCaption = '$finalCaption\n[${_textOverlay!}]'.trim();
      }
      if (_partnerLink != null && _partnerLink!.isNotEmpty) {
        finalCaption = '$finalCaption\n🛍️ $_partnerLink'.trim();
      }
      if (_abVariantCaption != null && _abVariantCaption!.isNotEmpty) {
        finalCaption = '$finalCaption\n($_abVariantCaption)'.trim();
      }

      final allTags = <String>[
        ..._taggedPeople,
        if (_selectedPlaylist != null && _selectedPlaylist!.isNotEmpty) _selectedPlaylist!,
        if (_activeFilter != 'normal') 'Filter:$_activeFilter',
        if (_monetizeTips) 'BakongTips',
      ];

      if (mounted) setState(() => _uploadProgress = 0.65);

      await ApiService().createReel(
        videoUrl: _selectedVideoUrl!,
        content: finalCaption,
        audioTitle: _audioTitle,
        location: _selectedLocation,
        spaceId: _selectedSpaceId,
        tags: allTags.isEmpty ? null : allTags,
        isBoosted: _boostReel,
        isAiGenerated: _aiLabelEnabled,
        shareToStory: _shareToStory,
      );

      if (mounted) {
        setState(() => _uploadProgress = 1.0);
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        setState(() => _isPublishing = false);
        Navigator.pop(context);
        widget.onReelCreated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  void _showAudioPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('ជ្រើសរើសសំឡេង / តន្ត្រី (Audio Track)', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Original Audio - Spaces Cambodia'),
            onPressed: () {
              setState(() => _audioTitle = 'Original Audio - Spaces Cambodia');
              Navigator.pop(ctx);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('🎵 ភ្លេងការបុរាណខ្មែរ (Khmer Traditional Vibes)'),
            onPressed: () {
              setState(() => _audioTitle = 'ភ្លេងការបុរាណខ្មែរ (Traditional)');
              Navigator.pop(ctx);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('🔥 Trending Beat Cambodia 2026'),
            onPressed: () {
              setState(() => _audioTitle = 'Trending Beat Cambodia 2026');
              Navigator.pop(ctx);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('✨ Lo-Fi Chill Phnom Penh Night'),
            onPressed: () {
              setState(() => _audioTitle = 'Lo-Fi Chill Phnom Penh Night');
              Navigator.pop(ctx);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('បោះបង់ (Cancel)'),
        ),
      ),
    );
  }

  void _showFilterPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('បែបផែនពណ៌ (Color Effects & Filters)', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('ធម្មតា (Normal)'),
            onPressed: () {
              setState(() => _activeFilter = 'normal');
              Navigator.pop(ctx);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('☀️ កក់ក្តៅ (Warm Golden)'),
            onPressed: () {
              setState(() => _activeFilter = 'warm');
              Navigator.pop(ctx);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('🎬 ស៊ីណេម៉ា (Cinematic Teal)'),
            onPressed: () {
              setState(() => _activeFilter = 'cinema');
              Navigator.pop(ctx);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('🟣 នេអុង (Cyber Neon)'),
            onPressed: () {
              setState(() => _activeFilter = 'neon');
              Navigator.pop(ctx);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('🖤 សខ្មៅ (Monochrome B&W)'),
            onPressed: () {
              setState(() => _activeFilter = 'mono');
              Navigator.pop(ctx);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('រួចរាល់ (Done)'),
        ),
      ),
    );
  }

  void _showTextOverlayDialog() {
    final textCtrl = TextEditingController(text: _textOverlay ?? '');
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('បញ្ចូលអត្ថបទលើ Reel'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: textCtrl,
            placeholder: 'សរសេរអក្សរលើវីដេអូ...',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('លុប'),
            onPressed: () {
              setState(() => _textOverlay = null);
              Navigator.pop(ctx);
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('ដាក់'),
            onPressed: () {
              setState(() => _textOverlay = textCtrl.text.trim().isEmpty ? null : textCtrl.text.trim());
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showStickerPicker() {
    final stickers = ['🔥', '❤️', '🇰🇭', '🚀', '✨', '🎉', '💯', '👏', '😍', '☕', '🌟', '🎬'];
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 200,
        color: const Color(0xFF1C1C1E),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'ជ្រើសរើសស្ទីកគ័រ / Emoji',
              style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: stickers.map((stk) {
                return GestureDetector(
                  onTap: () {
                    setState(() => _stickerOverlay = stk);
                    Navigator.pop(ctx);
                  },
                  child: Text(stk, style: const TextStyle(fontSize: 32)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  ColorFilter? _getFilterMatrix() {
    switch (_activeFilter) {
      case 'warm':
        return const ColorFilter.matrix([
          1.1, 0, 0, 0, 15,
          0, 1.0, 0, 0, 5,
          0, 0, 0.9, 0, -10,
          0, 0, 0, 1, 0,
        ]);
      case 'cinema':
        return const ColorFilter.matrix([
          0.9, 0, 0, 0, 0,
          0, 1.1, 0, 0, 10,
          0, 0, 1.2, 0, 20,
          0, 0, 0, 1, 0,
        ]);
      case 'neon':
        return const ColorFilter.matrix([
          1.2, 0, 0, 0, 20,
          0, 0.8, 0, 0, -10,
          0, 0, 1.3, 0, 30,
          0, 0, 0, 1, 0,
        ]);
      case 'mono':
        return const ColorFilter.matrix([
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _step == 0
              ? _buildStep1Picker()
              : _step == 1
                  ? _buildStep2EditPreview()
                  : _buildStep3PublishSettings(),
        ),
      ),
    );
  }

  // ==========================================
  // STEP 1: MEDIA & CAMERA PICKER (55072eb0.jpg)
  // ==========================================
  Widget _buildStep1Picker() {
    return Column(
      key: const ValueKey('step_1_picker'),
      children: [
        // Top Header: [X] | បង្កើតរ៉េល | [⚙️]
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.xmark, color: CupertinoColors.white, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
              const Text(
                'បង្កើតរ៉េល',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _showReelPreferencesSheet,
                child: const Icon(CupertinoIcons.gear, color: CupertinoColors.white, size: 24),
              ),
            ],
          ),
        ),

        // 5 Circular Action Buttons: កាមេរ៉ា, វិចិត្រសាល, តន្ត្រី, គំរូ, AI Label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTopRoundAction(CupertinoIcons.camera_fill, 'ថតកាមេរ៉ា', () => _pickVideoFromDevice(captureCamera: true)),
              _buildTopRoundAction(CupertinoIcons.photo_on_rectangle, 'វិចិត្រសាល', () => _pickVideoFromDevice(captureCamera: false)),
              _buildTopRoundAction(CupertinoIcons.music_note, 'តន្ត្រី', _showAudioPicker),
              _buildTopRoundAction(CupertinoIcons.sparkles, 'បែបផែន', _showFilterPicker),
              _buildTopRoundAction(
                CupertinoIcons.tag_fill,
                _aiLabelEnabled ? 'AI: បើក' : 'AI Label',
                () => setState(() => _aiLabelEnabled = !_aiLabelEnabled),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        Container(height: 0.5, color: const Color(0xFF2C2C2E)),

        // Subheader: វីដេអូរបស់អ្នក | [+ រើសពីទូរស័ព្ទ]
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _userPreviousVideos.isEmpty ? 'ថត ឬជ្រើសរើសវីដេអូពិត' : 'វីដេអូរបស់អ្នក (${_userPreviousVideos.length})',
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () => _pickVideoFromDevice(captureCamera: false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.folder_open, color: CupertinoColors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'រើសពីទូរស័ព្ទ',
                        style: TextStyle(color: CupertinoColors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Real Device Camera, Phone Gallery Picker & User's Real Previous Videos
        Expanded(
          child: _isLoadingClips
              ? const Center(child: CupertinoActivityIndicator(color: CupertinoColors.white, radius: 14))
              : GridView.builder(
                  padding: const EdgeInsets.all(6),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: _userPreviousVideos.length + 2,
                  itemBuilder: (ctx, idx) {
                    // Slot 0: Open Camera
                    if (idx == 0) {
                      return GestureDetector(
                        onTap: () => _pickVideoFromDevice(captureCamera: true),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF3A3B3C)),
                          ),
                          child: Center(
                            child: _isUploading
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CupertinoActivityIndicator(color: CupertinoColors.white, radius: 14),
                                      const SizedBox(height: 8),
                                      Text(
                                        'កំពុងផ្ទុក ${(_uploadProgress * 100).toInt()}%...',
                                        style: const TextStyle(color: CupertinoColors.white, fontSize: 11),
                                      ),
                                    ],
                                  )
                                : const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.camera_fill, color: Color(0xFF007AFF), size: 34),
                                      SizedBox(height: 8),
                                      Text(
                                        'ថតកាមេរ៉ា\n(Camera)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: CupertinoColors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      );
                    }

                    // Slot 1: Open Phone Gallery
                    if (idx == 1) {
                      return GestureDetector(
                        onTap: () => _pickVideoFromDevice(captureCamera: false),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF122338),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.6)),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.photo_on_rectangle, color: Color(0xFF34C759), size: 34),
                                SizedBox(height: 8),
                                Text(
                                  'ជ្រើសរើសវីដេអូ\nពីទូរស័ព្ទ',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: CupertinoColors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final realPost = _userPreviousVideos[idx - 2];
                    final clipUrl = realPost.videoUrl ?? realPost.imageUrl ?? '';
                    return GestureDetector(
                      onTap: () {
                        if (clipUrl.isEmpty) return;
                        setState(() {
                          _selectedVideoUrl = clipUrl;
                          _step = 1; // Go to Step 2 Edit
                        });
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              color: const Color(0xFF1C1C1E),
                              child: const Center(
                                child: Icon(CupertinoIcons.play_circle_fill, color: CupertinoColors.white, size: 36),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                color: Colors.black.withOpacity(0.65),
                                child: Text(
                                  realPost.content.isNotEmpty ? realPost.content : 'Reel របស់អ្នក',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: CupertinoColors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
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
      ],
    );
  }

  Widget _buildTopRoundAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF2C2C2E),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: CupertinoColors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: CupertinoColors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 2: EDIT & PREVIEW CANVAS (bea823b8.jpg)
  // ==========================================
  Widget _buildStep2EditPreview() {
    Widget videoWidget = WebVideoPlayerWidget(
      videoUrl: _selectedVideoUrl!,
      autoPlay: true,
      isLooping: true,
      showControls: false,
      isActive: true,
      fit: BoxFit.cover,
    );

    final matrix = _getFilterMatrix();
    if (matrix != null) {
      videoWidget = ColorFiltered(
        colorFilter: matrix,
        child: videoWidget,
      );
    }

    return Stack(
      key: const ValueKey('step_2_edit'),
      fit: StackFit.expand,
      children: [
        // Fullscreen Video Preview
        videoWidget,

        // Optional Text Overlay
        if (_textOverlay != null)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _textOverlay!,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
            ),
          ),

        // Optional Sticker Overlay
        if (_stickerOverlay != null)
          Positioned(
            top: 140,
            left: 40,
            child: Text(_stickerOverlay!, style: const TextStyle(fontSize: 48)),
          ),

        // Top Controls: [<] | [🎵* បញ្ចូលសំឡេង / រកមើលការណែនាំ] | [...]
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.chevron_back, color: CupertinoColors.white, size: 28),
                onPressed: () => setState(() => _step = 0),
              ),

              // Floating Audio Pill
              GestureDetector(
                onTap: _showAudioPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.music_note, color: CupertinoColors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _audioTitle.length > 22 ? '${_audioTitle.substring(0, 20)}...' : _audioTitle,
                        style: const TextStyle(color: CupertinoColors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),

              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _showEditMoreSheet,
                child: const Icon(CupertinoIcons.ellipsis, color: CupertinoColors.white, size: 24),
              ),
            ],
          ),
        ),

        // Bottom Tools: សំឡេង, កែ, បែបផែន, អត្ថបទ, ស្ទីកគ័រ, [→ បន្ទាប់]
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBottomTool(CupertinoIcons.music_note_list, 'សំឡេង', _showAudioPicker),
              _buildBottomTool(CupertinoIcons.scissors, 'កែ', () {
                setState(() {
                  _videoSpeed = _videoSpeed == 1.0 ? 1.5 : (_videoSpeed == 1.5 ? 2.0 : 1.0);
                });
              }),
              _buildBottomTool(CupertinoIcons.sparkles, 'បែបផែន', _showFilterPicker),
              _buildBottomTool(CupertinoIcons.textformat, 'អត្ថបទ', _showTextOverlayDialog),
              _buildBottomTool(CupertinoIcons.smiley, 'ស្ទីកគ័រ', _showStickerPicker),

              // Next Button [→ បន្ទាប់]
              GestureDetector(
                onTap: () => setState(() => _step = 2), // Move to Step 3
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFF007AFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(CupertinoIcons.arrow_right, color: CupertinoColors.white, size: 22),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'បន្ទាប់',
                      style: TextStyle(color: CupertinoColors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomTool(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(icon, color: CupertinoColors.white, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: CupertinoColors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 3: SETTINGS & PUBLISH (038c59a4.jpg)
  // ==========================================
  Widget _buildStep3PublishSettings() {
    return Column(
      key: const ValueKey('step_3_settings'),
      children: [
        // Header: [<] | ការកំណត់ Reel
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.chevron_back, color: CupertinoColors.white, size: 26),
                onPressed: () => setState(() => _step = 1), // Back to Step 2
              ),
              const SizedBox(width: 8),
              const Text(
                'ការកំណត់ Reel',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Container(height: 0.5, color: const Color(0xFF2C2C2E)),

        // Body with Scrollable Settings
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Thumbnail + Caption Field
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video Thumbnail
                    Container(
                      width: 90,
                      height: 130,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF3A3B3C)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            WebVideoPlayerWidget(
                              videoUrl: _selectedVideoUrl!,
                              autoPlay: false,
                              isLooping: false,
                              showControls: false,
                              isActive: false,
                              fit: BoxFit.cover,
                            ),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(CupertinoIcons.photo, color: CupertinoColors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Caption and Hashtags Text Field
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CupertinoTextField(
                            controller: _captionCtrl,
                            placeholder: 'ពណ៌នារីលរបស់អ្នក... អ្នកក៏អាចបញ្ចូលហាស់ថេកនៅទីនេះបានដែរ។',
                            placeholderStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                            style: const TextStyle(color: CupertinoColors.white, fontSize: 14),
                            maxLines: 4,
                            decoration: const BoxDecoration(color: Colors.transparent),
                          ),
                          const SizedBox(height: 8),

                          // Quick Hashtags Chips
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildQuickHashtag('#Spaces'),
                              _buildQuickHashtag('#Cambodia'),
                              _buildQuickHashtag('#Reels'),
                              _buildQuickHashtag('#Khmer'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                Container(height: 0.5, color: const Color(0xFF2C2C2E)),
                const SizedBox(height: 10),

                // Settings List Items matching 038c59a4.jpg
                // 1. + បញ្ចូលស្លាក AI (AI Label toggle)
                _buildSettingRow(
                  icon: CupertinoIcons.plus,
                  title: 'បញ្ចូលស្លាក AI',
                  subtitle: 'យើងតម្រូវឱ្យអ្នកដាក់ស្លាកមាតិកាជាក់ស្ដែងជាក់លាក់ដែលបង្កើតដោយប្រើ AI។ ស្វែងយល់បន្ថែម',
                  trailing: CupertinoSwitch(
                    value: _aiLabelEnabled,
                    activeColor: const Color(0xFF007AFF),
                    onChanged: (val) => setState(() => _aiLabelEnabled = val),
                  ),
                ),

                // 2. 📍 ទីតាំង (Location Picker)
                _buildSettingRow(
                  icon: CupertinoIcons.location_solid,
                  title: 'ទីតាំង',
                  subtitle: _selectedLocation ?? 'ជ្រើសរើសទីតាំងនៅកម្ពុជា',
                  onTap: () async {
                    final loc = await LocationPickerSheet.show(context, initialLocation: _selectedLocation);
                    if (loc != null) {
                      setState(() => _selectedLocation = loc);
                    }
                  },
                ),

                // 3. ↗️ ចែករំលែកទៅក្រុម (Share to Real Space/Group)
                _buildSettingRow(
                  icon: CupertinoIcons.arrowshape_turn_up_right_fill,
                  title: 'ចែករំលែកទៅក្រុម / Space',
                  subtitle: _selectedGroup ?? 'ជ្រើសរើស Space ដែលអ្នកចង់ចែករំលែក',
                  onTap: _openGroupSpacePicker,
                ),

                // 4. 🛍️ បញ្ចូលតំណភ្ជាប់ដៃគូផ្សព្វផ្សាយ (Branded Content)
                _buildSettingRow(
                  icon: CupertinoIcons.bag_fill,
                  title: 'បញ្ចូលតំណភ្ជាប់ដៃគូផ្សព្វផ្សាយ',
                  subtitle: _partnerLink ?? 'រួមបញ្ចូលតំណទៅក្នុងផលិតផលដៃគូផ្សព្វផ្សាយនៅក្នុងរ៉េលរបស់អ្នក។',
                  onTap: _promptPartnerLink,
                ),

                // 5. ▶️ បញ្ចូលទៅក្នុងបញ្ជីចាក់ (Add to Playlist)
                _buildSettingRow(
                  icon: CupertinoIcons.play_rectangle_fill,
                  title: 'បញ្ចូលទៅក្នុងបញ្ជីចាក់',
                  subtitle: _selectedPlaylist ?? 'បង្កើត ឬជ្រើសរើសឈ្មោះបញ្ជីចាក់ (Playlist)',
                  onTap: _promptPlaylistDialog,
                ),

                // 6. 🏷️ ដាក់ស្លាកមនុស្ស (Tag Real People)
                _buildSettingRow(
                  icon: CupertinoIcons.tag_fill,
                  title: 'ដាក់ស្លាកមនុស្ស',
                  subtitle: _taggedPeople.isEmpty ? 'ស្វែងរក និងដាក់ស្លាកគណនីមិត្តភក្តិ' : _taggedPeople.join(', '),
                  onTap: _openPeopleTagPicker,
                ),

                // 7. 📖 ចែករំលែកទៅរឿងរបស់អ្នក (Share to Story)
                _buildSettingRow(
                  icon: CupertinoIcons.book_fill,
                  title: 'ចែករំលែកទៅរឿងរបស់អ្នក',
                  subtitle: '• ជួយឱ្យវាផ្សាយទៅដល់អ្នកតាមដានរបស់អ្នក',
                  trailing: CupertinoSwitch(
                    value: _shareToStory,
                    activeColor: const Color(0xFF007AFF),
                    onChanged: (val) => setState(() => _shareToStory = val),
                  ),
                ),

                // 8. 📢 បង្កើនការផ្សព្វផ្សាយ Reel (Boost Reel)
                _buildSettingRow(
                  icon: CupertinoIcons.speaker_2_fill,
                  title: 'បង្កើនការផ្សព្វផ្សាយ Reel',
                  subtitle: 'បង្ហាញរ៉េលជាអាទិភាពនៅលើ Feed',
                  trailing: CupertinoSwitch(
                    value: _boostReel,
                    activeColor: const Color(0xFF007AFF),
                    onChanged: (val) => setState(() => _boostReel = val),
                  ),
                ),

                // 9. 🧪 ការធ្វើតេស្ត A/B (A/B Caption Variant)
                _buildSettingRow(
                  icon: CupertinoIcons.lab_flask,
                  title: 'ការធ្វើតេស្ត A/B',
                  subtitle: _abVariantCaption != null ? 'ចំណងជើង B៖ $_abVariantCaption' : 'បន្ថែមចំណងជើងបន្ទាប់ (Variant B)',
                  onTap: _promptAbCaptionTest,
                ),

                // 10. 💰 ការរកលុយ (Bakong KHQR Monetization)
                _buildSettingRow(
                  icon: CupertinoIcons.money_dollar_circle_fill,
                  title: 'ការរកលុយ (Bakong KHQR)',
                  subtitle: _monetizeTips
                      ? 'បានបើកទទួលប្រាក់ឧបត្ថម្ភទៅកាន់ ${ApiService().currentUser?.bakongAccountId ?? ""}'
                      : (ApiService().currentUser?.bakongAccountId?.isNotEmpty == true
                          ? 'បើកការទទួលប្រាក់ឧបត្ថម្ភទៅ ${ApiService().currentUser!.bakongAccountId}'
                          : 'ភ្ជាប់ Bakong ID ដើម្បីទទួលប្រាក់ឧបត្ថម្ភ'),
                  onTap: _openMonetizationSetup,
                ),
              ],
            ),
          ),
        ),

        // Bottom Sticky Action Bar: [💾 Save Draft] | [ចែករំលែកឥឡូវនេះ (Share Now)]
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            border: Border(top: BorderSide(color: Color(0xFF2C2C2E))),
          ),
          child: Row(
            children: [
              // Save Draft Button
              CupertinoButton(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(12),
                child: const Icon(CupertinoIcons.archivebox, color: CupertinoColors.white, size: 20),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(width: 12),

              // Share Now Button
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _isPublishing ? null : _publishReel,
                  child: _isPublishing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CupertinoActivityIndicator(color: CupertinoColors.white),
                            const SizedBox(width: 8),
                            Text(
                              'កំពុងបង្ហោះ ${(_uploadProgress * 100).toInt()}%...',
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'ចែករំលែកឥឡូវនេះ',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickHashtag(String tag) {
    return GestureDetector(
      onTap: () {
        if (!_captionCtrl.text.contains(tag)) {
          _captionCtrl.text = '${_captionCtrl.text} $tag'.trim();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          tag,
          style: const TextStyle(color: Color(0xFF007AFF), fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF2C2C2E),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: CupertinoColors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(CupertinoIcons.chevron_forward, color: Color(0xFF8E8E93), size: 16),
                ),
          ],
        ),
      ),
    );
  }

  void _promptPartnerLink() {
    final linkCtrl = TextEditingController(text: _partnerLink ?? '');
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('បញ្ចូលតំណភ្ជាប់ដៃគូផ្សព្វផ្សាយ'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: linkCtrl,
            placeholder: 'https://...',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('បោះបង់'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('យល់ព្រម'),
            onPressed: () {
              setState(() => _partnerLink = linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim());
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showReelPreferencesSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => CupertinoActionSheet(
          title: const Text('ការកំណត់ Reel (Reel Preferences)', style: TextStyle(fontWeight: FontWeight.w700)),
          message: Text(
            'កម្រិតគុណភាព៖ HD (រហូតដល់ 250MB ផ្ទុកលើ Cloudflare R2)\nចែករំលែកទៅ Story៖ ${_shareToStory ? "បើក" : "បិទ"} • AI Label៖ ${_aiLabelEnabled ? "បើក" : "បិទ"}',
          ),
          actions: [
            CupertinoActionSheetAction(
              child: Text(_shareToStory ? '✓ ចែករំលែកទៅ Story ដោយស្វ័យប្រវត្តិ (បើក)' : 'ចែករំលែកទៅ Story ដោយស្វ័យប្រវត្តិ (បិទ)'),
              onPressed: () {
                setState(() => _shareToStory = !_shareToStory);
                setModalState(() {});
              },
            ),
            CupertinoActionSheetAction(
              child: Text(_aiLabelEnabled ? '✓ បញ្ចូលស្លាក AI (បើក)' : 'បញ្ចូលស្លាក AI (បិទ)'),
              onPressed: () {
                setState(() => _aiLabelEnabled = !_aiLabelEnabled);
                setModalState(() {});
              },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('រួចរាល់ (Done)'),
          ),
        ),
      ),
    );
  }

  void _showEditMoreSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('ជម្រើសកែវីដេអូ (ល្បឿនបច្ចុប្បន្ន៖ ${_videoSpeed}x)'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('ប្តូរវីដេអូថ្មីពីទូរស័ព្ទ (Pick New Video)'),
            onPressed: () {
              Navigator.pop(ctx);
              _pickVideoFromDevice(captureCamera: false);
            },
          ),
          CupertinoActionSheetAction(
            child: Text(_videoSpeed == 1.0 ? '✓ ល្បឿនធម្មតា (1.0x)' : 'ល្បឿនធម្មតា (1.0x)'),
            onPressed: () {
              setState(() => _videoSpeed = 1.0);
              Navigator.pop(ctx);
            },
          ),
          CupertinoActionSheetAction(
            child: Text(_videoSpeed == 1.5 ? '✓ ល្បឿនលឿន (1.5x)' : 'ល្បឿនលឿន (1.5x)'),
            onPressed: () {
              setState(() => _videoSpeed = 1.5);
              Navigator.pop(ctx);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              setState(() {
                _textOverlay = null;
                _stickerOverlay = null;
                _activeFilter = 'normal';
              });
              Navigator.pop(ctx);
            },
            child: const Text('សម្អាតអក្សរ និងស្ទីកគ័រ (Clear Overlays)'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('បោះបង់'),
        ),
      ),
    );
  }

  Future<void> _openGroupSpacePicker() async {
    final spaces = await ApiService().fetchSpaces();
    if (!mounted) return;
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('ជ្រើសរើស Space / ក្រុម'),
        actions: spaces.isEmpty
            ? [
                CupertinoActionSheetAction(
                  child: const Text('Spaces កម្ពុជា (Public)'),
                  onPressed: () {
                    setState(() {
                      _selectedSpaceId = 'public';
                      _selectedGroup = 'Spaces កម្ពុជា (Public)';
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ]
            : spaces.map((sp) {
                return CupertinoActionSheetAction(
                  child: Text(sp.name),
                  onPressed: () {
                    setState(() {
                      _selectedSpaceId = sp.id;
                      _selectedGroup = sp.name;
                    });
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('បោះបង់'),
        ),
      ),
    );
  }

  void _promptPlaylistDialog() {
    final ctrl = TextEditingController(text: _selectedPlaylist ?? '');
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('ឈ្មោះបញ្ជីចាក់ (Playlist)'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            placeholder: 'ឧ. ដំណើរកម្សាន្ត, អាហារខ្មែរ...',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('លុបចេញ'),
            onPressed: () {
              setState(() => _selectedPlaylist = null);
              Navigator.pop(ctx);
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('រក្សាទុក'),
            onPressed: () {
              setState(() => _selectedPlaylist = ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openPeopleTagPicker() async {
    final users = await ApiService().searchUsers('');
    if (!mounted) return;
    final me = ApiService().currentUser?.id;
    final candidates = users.where((u) => u.id != me).take(12).toList();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('ដាក់ស្លាកមិត្តភក្តិ (Tag People)'),
        actions: candidates.isEmpty
            ? [
                CupertinoActionSheetAction(
                  child: const Text('មិនទាន់មានគណនីផ្សេងទៀតទេ'),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ]
            : candidates.map((u) {
                final handle = '@${u.username}';
                final already = _taggedPeople.contains(handle);
                return CupertinoActionSheetAction(
                  child: Text(already ? '✓ ${u.name} ($handle)' : '${u.name} ($handle)'),
                  onPressed: () {
                    setState(() {
                      if (already) {
                        _taggedPeople.remove(handle);
                      } else {
                        _taggedPeople.add(handle);
                      }
                    });
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('រួចរាល់'),
        ),
      ),
    );
  }

  void _promptAbCaptionTest() {
    final ctrl = TextEditingController(text: _abVariantCaption ?? '');
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('ការធ្វើតេស្ត A/B Caption'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            placeholder: 'សរសេរចំណងជើងបន្ថែម (Variant B)...',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('បោះបង់'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('រក្សាទុក'),
            onPressed: () {
              setState(() => _abVariantCaption = ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _openMonetizationSetup() {
    final existingId = ApiService().currentUser?.bakongAccountId?.trim() ?? '';
    if (existingId.isNotEmpty) {
      setState(() => _monetizeTips = !_monetizeTips);
      return;
    }
    final bakongCtrl = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('ភ្ជាប់ Bakong KHQR ដើម្បីរកលុយ'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: bakongCtrl,
            placeholder: 'ឧ. name@bkrt',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('បោះបង់'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('ភ្ជាប់គណនី'),
              onPressed: () async {
              final val = bakongCtrl.text.trim();
              if (val.isEmpty || !val.contains('@')) return;
              Navigator.pop(ctx);
              final user = ApiService().currentUser;
              final updated = await ApiService().updateStore(
                storeName: (user?.storeName != null && user!.storeName!.isNotEmpty)
                    ? user.storeName!
                    : (user?.name ?? 'Creator Store'),
                storePhone: (user?.storePhone != null && user!.storePhone!.isNotEmpty)
                    ? user.storePhone!
                    : (user?.phone ?? ''),
                bakongAccountId: val,
              );
              if (updated != null && mounted) {
                setState(() => _monetizeTips = true);
              }
            },
          ),
        ],
      ),
    );
  }
}
