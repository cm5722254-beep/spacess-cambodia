import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
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
  String? _selectedGroup;
  String? _partnerLink;
  String? _selectedPlaylist;
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

  // Preset sample videos for instant Reel creation
  final List<Map<String, String>> _sampleGalleryClips = [
    {
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      'duration': '00:15',
      'title': 'Cambodia Horizon',
      'thumb': 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=500&q=80',
    },
    {
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      'duration': '00:16',
      'title': 'Sunset at Siem Reap',
      'thumb': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
    },
    {
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
      'duration': '01:05',
      'title': 'Phnom Penh City Night',
      'thumb': 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500&q=80',
    },
    {
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyBlazes.mp4',
      'duration': '02:00',
      'title': 'Bokor Mountain Trip',
      'thumb': 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=500&q=80',
    },
    {
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
      'duration': '02:00',
      'title': 'Koh Rong Beach Vibes',
      'thumb': 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=500&q=80',
    },
    {
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4',
      'duration': '02:00',
      'title': 'Cambodian Food Journey',
      'thumb': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickVideoFromDevice();
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
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => _uploadProgress = 0.65);

      await ApiService().createReel(
        videoUrl: _selectedVideoUrl!,
        content: _captionCtrl.text.trim(),
        audioTitle: _audioTitle,
        location: _selectedLocation,
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
                child: const Icon(CupertinoIcons.gear, color: CupertinoColors.white, size: 24),
                onPressed: () {},
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
              _buildTopRoundAction(CupertinoIcons.square_stack_3d_up_fill, 'គំរូ', () {}),
              _buildTopRoundAction(CupertinoIcons.sparkles, 'AI Label', () => setState(() => _aiLabelEnabled = !_aiLabelEnabled)),
            ],
          ),
        ),

        const SizedBox(height: 8),
        Container(height: 0.5, color: const Color(0xFF2C2C2E)),

        // Subheader: វិចិត្រសាល ∨ | [🖼️] ជ្រើសរើសច្រើន
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Text(
                    'វិចិត្រសាល',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(CupertinoIcons.chevron_down, color: CupertinoColors.white, size: 14),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: const [
                    Icon(CupertinoIcons.square_on_square, color: CupertinoColors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'ជ្រើសរើសច្រើន',
                      style: TextStyle(color: CupertinoColors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Device Gallery Trigger & Sample Clips Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
              childAspectRatio: 0.68,
            ),
            itemCount: _sampleGalleryClips.length + 1,
            itemBuilder: (ctx, idx) {
              // First slot: Open Camera (ថតកាមេរ៉ា)
              if (idx == 0) {
                return GestureDetector(
                  onTap: () => _pickVideoFromDevice(captureCamera: true),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
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
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(CupertinoIcons.camera_fill, color: Color(0xFF007AFF), size: 36),
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

              final clip = _sampleGalleryClips[idx - 1];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedVideoUrl = clip['url'];
                    _step = 1; // Go to Step 2 Edit
                  });
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      clip['thumb']!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF2C2C2E)),
                    ),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          clip['duration']!,
                          style: const TextStyle(color: CupertinoColors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
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
                child: const Icon(CupertinoIcons.ellipsis, color: CupertinoColors.white, size: 24),
                onPressed: () {},
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

                // 3. ↗️ ចែករំលែកទៅក្រុម (Share to groups)
                _buildSettingRow(
                  icon: CupertinoIcons.arrowshape_turn_up_right_fill,
                  title: 'ចែករំលែកទៅក្រុម',
                  subtitle: _selectedGroup ?? 'ឥឡូវនេះ អ្នកអាចចែករំលែកដោយស្វ័យប្រវត្តិទៅក្រុមដែលពាក់ព័ន្ធ។',
                  onTap: () {
                    setState(() => _selectedGroup = 'ក្រុម Spaces Cambodia Creator Club');
                  },
                ),

                // 4. 🛍️ បញ្ចូលតំណភ្ជាប់ដៃគូផ្សព្វផ្សាយ (Branded Content)
                _buildSettingRow(
                  icon: CupertinoIcons.bag_fill,
                  title: 'បញ្ចូលតំណភ្ជាប់ដៃគូផ្សព្វផ្សាយ',
                  subtitle: _partnerLink ?? 'រួមបញ្ចូលតំណទៅក្នុងផលិតផលដៃគូផ្សព្វផ្សាយនៅក្នុងរ៉េលរបស់អ្នក ហើយអ្នកអាចទទួលបានកម្រៃជើងសារ។',
                  onTap: () {
                    _promptPartnerLink();
                  },
                ),

                // 5. ▶️ បញ្ចូលទៅក្នុងបញ្ជីចាក់ (Add to Playlist)
                _buildSettingRow(
                  icon: CupertinoIcons.play_rectangle_fill,
                  title: 'បញ្ចូលទៅក្នុងបញ្ជីចាក់',
                  subtitle: _selectedPlaylist ?? 'បង្កើត ឬជ្រើសរើសបញ្ជីចាក់ (Playlist)',
                  onTap: () {
                    setState(() => _selectedPlaylist = 'Top Cambodian Reels 2026');
                  },
                ),

                // 6. 🏷️ ដាក់ស្លាកមនុស្ស (Tag People)
                _buildSettingRow(
                  icon: CupertinoIcons.tag_fill,
                  title: 'ដាក់ស្លាកមនុស្ស',
                  subtitle: _taggedPeople.isEmpty ? 'នេះរាប់បញ្ចូលទាំងដៃគូផងដែរ' : _taggedPeople.join(', '),
                  onTap: () {
                    setState(() => _taggedPeople.add('@vin_socheat'));
                  },
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
                  subtitle: 'ផ្សព្វផ្សាយទៅកាន់អ្នកប្រើប្រាស់រាប់ម៉ឺននាក់',
                  trailing: CupertinoSwitch(
                    value: _boostReel,
                    activeColor: const Color(0xFF007AFF),
                    onChanged: (val) => setState(() => _boostReel = val),
                  ),
                ),

                // 9. 🧪 ការធ្វើតេស្ត A/B (A/B Testing)
                _buildSettingRow(
                  icon: CupertinoIcons.lab_flask,
                  title: 'ការធ្វើតេស្ត A/B',
                  subtitle: 'សាកល្បង Thumbnail និង Caption ច្រើនបែប',
                  onTap: () {},
                ),

                // 10. 💰 ការរកលុយ (Monetization)
                _buildSettingRow(
                  icon: CupertinoIcons.money_dollar_circle_fill,
                  title: 'ការរកលុយ',
                  subtitle: 'ផ្ទៀងផ្ទាត់ និងទទួលប្រាក់ចំណូលតាម Bakong KHQR',
                  onTap: () {},
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
}
