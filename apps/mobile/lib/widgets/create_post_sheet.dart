import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, LinearProgressIndicator, AlwaysStoppedAnimation;
import '../models/post_model.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../utils/media_picker_helper.dart';
import 'media_image_view.dart';
import 'location_picker_sheet.dart';

class CreatePostSheet extends StatefulWidget {
  final List<SpaceModel> spaces;
  final Function(PostModel newPost) onPostCreated;

  const CreatePostSheet({
    super.key,
    required this.spaces,
    required this.onPostCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required List<SpaceModel> spaces,
    required Function(PostModel newPost) onPostCreated,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CreatePostSheet(spaces: spaces, onPostCreated: onPostCreated),
    );
  }

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  late String selectedSpaceId;
  String selectedCircle = 'Public / សាធារណៈ';
  String? selectedLocation;
  String selectedTemplate = 'clean';
  String selectedMood = '';
  String? selectedMusic;
  final List<String> _taggedPeople = [];
  bool _shareToStory = false;
  bool isSubmitting = false;
  bool isImporting = false;
  String? _importedMedia;
  bool _showColorStrip = false;

  static const List<Map<String, dynamic>> postBackgroundThemes = [
    {'id': 'clean', 'label': 'គ្មាន', 'colors': null},
    {
      'id': 'ocean',
      'label': 'Ocean',
      'colors': [Color(0xFF007AFF), Color(0xFF5856D6)],
    },
    {
      'id': 'sunset',
      'label': 'Sunset',
      'colors': [Color(0xFFFF2D55), Color(0xFFFF9500)],
    },
    {
      'id': 'emerald',
      'label': 'Emerald',
      'colors': [Color(0xFF34C759), Color(0xFF007AFF)],
    },
    {
      'id': 'royal',
      'label': 'Royal',
      'colors': [Color(0xFF5856D6), Color(0xFFAF52DE)],
    },
    {
      'id': 'darkness',
      'label': 'Dark',
      'colors': [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
    },
    {
      'id': 'fire',
      'label': 'Fire',
      'colors': [Color(0xFFFF3B30), Color(0xFFFF9500)],
    },
    {
      'id': 'pink',
      'label': 'Pink',
      'colors': [Color(0xFFFF2D55), Color(0xFFFF375F)],
    },
  ];

  static const List<String> moodPresets = [
    '😊 រីករាយ',
    '❤️ មានក្តីស្រលាញ់',
    '🔥 ពេញដោយថាមពល',
    '☕ សម្រាកកាយ',
    '🎉 កំពុងអបអរសាទរ',
    '🚀 កំពុងធ្វើការ',
    '✨ មានអារម្មណ៍ល្អ',
    '🍕 កំពុងញ៉ាំអាហារ',
  ];

  @override
  void initState() {
    super.initState();
    selectedSpaceId = widget.spaces.isNotEmpty ? widget.spaces.first.id : 'space-public-1';
  }

  @override
  void dispose() {
    _contentController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _pickFromDevice() async {
    setState(() => isImporting = true);
    final media = await MediaPickerHelper.pickAndUploadMedia(accept: 'image/*,video/*');
    if (mounted) {
      setState(() {
        isImporting = false;
        if (media != null && media.isNotEmpty) {
          _importedMedia = media;
          _imageUrlController.text = media;
          selectedTemplate = 'clean'; // Cancel background theme if image is attached
        }
      });
    }
  }

  void _openLocationPicker() async {
    final loc = await LocationPickerSheet.show(context, initialLocation: selectedLocation);
    if (loc != null && mounted) {
      setState(() => selectedLocation = loc);
    }
  }

  void _openMusicPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('ជ្រើសរើសតន្ត្រីសម្រាប់ Post (Add Music)', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('🎵 Trending Khmer Pop 2026'),
            onPressed: () {
              setState(() => selectedMusic = 'Trending Khmer Pop 2026');
              Navigator.pop(ctx);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('✨ Lo-Fi Chill Phnom Penh Beats'),
            onPressed: () {
              setState(() => selectedMusic = 'Lo-Fi Chill Phnom Penh');
              Navigator.pop(ctx);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('🔥 Acoustic Sunset Vibe'),
            onPressed: () {
              setState(() => selectedMusic = 'Acoustic Sunset Vibe');
              Navigator.pop(ctx);
            },
          ),
          if (selectedMusic != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: const Text('ដកតន្ត្រីចេញ (Remove Music)'),
              onPressed: () {
                setState(() => selectedMusic = null);
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

  void _openFeelingPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('អារម្មណ៍ / សកម្មភាព (Feeling / Activity)', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: moodPresets.map((m) {
          return CupertinoActionSheetAction(
            child: Text(m),
            onPressed: () {
              setState(() => selectedMood = m);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            setState(() => selectedMood = '');
            Navigator.pop(ctx);
          },
          child: const Text('ជម្រះអារម្មណ៍ចេញ (Clear)'),
        ),
      ),
    );
  }

  void _openTagPeople() {
    final tagCtrl = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('ដាក់ស្លាកមនុស្ស / មិត្តភក្តិ'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: tagCtrl,
            placeholder: 'ឧ. @socheat, @dara...',
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
              if (tagCtrl.text.trim().isNotEmpty) {
                setState(() => _taggedPeople.add(tagCtrl.text.trim()));
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  double _uploadProgress = 0.0;

  void _submit() async {
    if (isSubmitting) return; // Strict Anti-Duplicate Submit Guard
    final text = _contentController.text.trim();
    if (text.isEmpty && _importedMedia == null) return;

    setState(() {
      isSubmitting = true;
      _uploadProgress = 0.2;
    });

    final finalMedia = _importedMedia ?? (_imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim());

    String enrichedContent = text;
    if (selectedMusic != null) {
      enrichedContent = '🎵 $selectedMusic\n$enrichedContent';
    }

    if (mounted) setState(() => _uploadProgress = 0.65);

    final newPost = await ApiService().createPost(
      content: enrichedContent,
      spaceId: selectedSpaceId,
      city: selectedLocation ?? 'Phnom Penh, Cambodia',
      circleName: selectedCircle,
      imageUrl: finalMedia,
      tags: ['SpacesCambodia', ..._taggedPeople],
      templateStyle: selectedTemplate == 'clean' ? null : selectedTemplate,
      moodTag: selectedMood.isEmpty ? null : selectedMood,
    );

    if (mounted) setState(() => _uploadProgress = 1.0);

    if (newPost != null && mounted) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      widget.onPostCreated(newPost);
      Navigator.pop(context);
    } else {
      if (mounted) {
        setState(() => isSubmitting = false);
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('ការបង្ហោះមិនជោគជ័យ'),
            content: const Text('មិនអាចបង្ហោះសារបានទេ សូមពិនិត្យមើលអ៊ីនធឺណិត ហើយព្យាយាមម្តងទៀត។'),
            actions: [
              CupertinoDialogAction(
                child: const Text('យល់ព្រម'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final currentUser = ApiService().currentUser;
    final userName = currentUser?.name ?? 'Vin Chan Socheat';
    final userAvatar = currentUser?.avatar ?? '/default_avatar.svg';

    final activeTheme = postBackgroundThemes.firstWhere(
      (t) => t['id'] == selectedTemplate,
      orElse: () => postBackgroundThemes[0],
    );
    final isColoredBg = activeTheme['colors'] != null && _importedMedia == null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: BoxDecoration(
        color: AppTheme.modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey4,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // Header matching c88e532b.jpg: [X] | សារបង្ហោះថ្មី | [បន្ទាប់]
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(CupertinoIcons.xmark, color: AppTheme.primaryText, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  'សារបង្ហោះថ្មី',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryText,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  color: isSubmitting ? const Color(0xFF34C759) : const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: isSubmitting ? null : _submit,
                  child: isSubmitting
                      ? Text(
                          '${(_uploadProgress * 100).toInt()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                        )
                      : const Text(
                          'បន្ទាប់',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (isSubmitting)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: isDark ? const Color(0xFF2C2F3E) : const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('កំពុងបង្ហោះសារ...', style: TextStyle(fontSize: 11, color: AppTheme.secondaryText)),
                      Text(
                        '${(_uploadProgress * 100).toInt()}%',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF007AFF)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Container(height: 0.5, color: AppTheme.divider),

          // Author Row & 4 Quick Pills underneath matching c88e532b.jpg
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MediaImageView(
                      url: userAvatar,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppTheme.primaryText,
                            ),
                          ),
                          if (selectedMood.isNotEmpty)
                            Text(
                              'កំពុងមានអារម្មណ៍ $selectedMood',
                              style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 4 Pills: 🎵 តន្ត្រី, 👥 ដាក់ស្លាក/សហការ, 📍 ទីតាំង, 😊 អារម្មណ៍/សកម្មភាព
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildQuickPill(
                        icon: CupertinoIcons.music_note,
                        label: selectedMusic != null ? '🎵 $selectedMusic' : 'តន្ត្រី',
                        isActive: selectedMusic != null,
                        onTap: _openMusicPicker,
                      ),
                      const SizedBox(width: 8),
                      _buildQuickPill(
                        icon: CupertinoIcons.person_2_fill,
                        label: _taggedPeople.isNotEmpty ? _taggedPeople.join(', ') : 'ដាក់ស្លាក/សហការ',
                        isActive: _taggedPeople.isNotEmpty,
                        onTap: _openTagPeople,
                      ),
                      const SizedBox(width: 8),
                      _buildQuickPill(
                        icon: CupertinoIcons.location_solid,
                        label: selectedLocation ?? 'ទីតាំង',
                        isActive: selectedLocation != null,
                        onTap: _openLocationPicker,
                      ),
                      const SizedBox(width: 8),
                      _buildQuickPill(
                        icon: CupertinoIcons.smiley,
                        label: selectedMood.isNotEmpty ? selectedMood : 'អារម្មណ៍/សកម្មភាព',
                        isActive: selectedMood.isNotEmpty,
                        onTap: _openFeelingPicker,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Canvas: Text Input & Live Background / Image Preview
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Colored Background Mode OR Normal Text
                  if (isColoredBg)
                    Container(
                      width: double.infinity,
                      height: 220,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: activeTheme['colors'] as List<Color>,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: CupertinoTextField(
                          controller: _contentController,
                          placeholder: 'តើអ្នកកំពុងគិតអ្វី?',
                          placeholderStyle: const TextStyle(color: CupertinoColors.white, fontSize: 20, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            shadows: [Shadow(blurRadius: 6, color: Colors.black26)],
                          ),
                          maxLines: 5,
                          decoration: const BoxDecoration(color: Colors.transparent),
                        ),
                      ),
                    )
                  else
                    CupertinoTextField(
                      controller: _contentController,
                      placeholder: 'តើអ្នកកំពុងគិតអ្វី?',
                      placeholderStyle: TextStyle(
                        color: AppTheme.secondaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      style: TextStyle(
                        color: AppTheme.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 6,
                      decoration: const BoxDecoration(color: Colors.transparent),
                    ),

                  const SizedBox(height: 12),

                  // Image / Video Attached Preview
                  if (_importedMedia != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            color: const Color(0xFF1C1C1E),
                            child: _importedMedia!.endsWith('.mp4') || _importedMedia!.endsWith('.mov')
                                ? const Center(child: Icon(CupertinoIcons.play_circle_fill, color: CupertinoColors.white, size: 54))
                                : MediaImageView(url: _importedMedia!, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _importedMedia = null),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(CupertinoIcons.xmark, color: CupertinoColors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Background Colors Strip (when toggled)
                  if (_showColorStrip) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: postBackgroundThemes.map((thm) {
                          final isSelected = selectedTemplate == thm['id'];
                          final colors = thm['colors'] as List<Color>?;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedTemplate = thm['id'];
                                _importedMedia = null;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: colors != null
                                    ? LinearGradient(colors: colors)
                                    : null,
                                color: colors == null ? const Color(0xFFE4E6EB) : null,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: colors == null
                                  ? const Icon(CupertinoIcons.clear, size: 16, color: CupertinoColors.black)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Horizontal Tool Cards matching c88e532b.jpg
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.divider)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildBottomCard(
                    icon: CupertinoIcons.photo_on_rectangle,
                    label: isImporting ? 'កំពុងផ្ទុក...' : 'វិចិត្រសាល',
                    onTap: _pickFromDevice,
                  ),
                  const SizedBox(width: 10),
                  _buildBottomCard(
                    icon: CupertinoIcons.camera_fill,
                    label: 'កាមេរ៉ា',
                    onTap: _pickFromDevice,
                  ),
                  const SizedBox(width: 10),
                  _buildBottomCard(
                    icon: CupertinoIcons.play_rectangle,
                    label: 'GIF',
                    onTap: () {
                      setState(() {
                        _contentController.text = '${_contentController.text} [GIF: Trending Cambodia]'.trim();
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  _buildBottomCard(
                    icon: CupertinoIcons.videocam_fill,
                    label: 'ការផ្សាយបន្តផ្ទាល់',
                    onTap: () {
                      setState(() {
                        _contentController.text = '${_contentController.text} 🔴 កំពុងផ្សាយផ្ទាល់លើ Spaces!'.trim();
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  _buildBottomCard(
                    icon: CupertinoIcons.paintbrush_fill,
                    label: 'ពណ៌ផ្ទៃខាងក្រោយ',
                    onTap: () => setState(() => _showColorStrip = !_showColorStrip),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Footer: [🌐 សាធារណៈ] | [📷 បិទ / Share to Story]
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF7F7F8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Audience selector
                GestureDetector(
                  onTap: () {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (ctx) => CupertinoActionSheet(
                        title: const Text('អ្នកណាអាចមើលឃើញការបង្ហោះនេះ? (Audience)'),
                        actions: [
                          CupertinoActionSheetAction(
                            child: const Text('🌐 សាធារណៈ (Public)'),
                            onPressed: () {
                              setState(() => selectedCircle = 'Public / សាធារណៈ');
                              Navigator.pop(ctx);
                            },
                          ),
                          CupertinoActionSheetAction(
                            child: const Text('👥 មិត្តភក្តិ (Friends Only)'),
                            onPressed: () {
                              setState(() => selectedCircle = 'Friends / មិត្តភក្តិ');
                              Navigator.pop(ctx);
                            },
                          ),
                          CupertinoActionSheetAction(
                            child: const Text('🔒 តែខ្ញុំប៉ុណ្ណោះ (Only Me)'),
                            onPressed: () {
                              setState(() => selectedCircle = 'Only Me / តែខ្ញុំ');
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
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.fieldBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.globe, size: 16, color: Color(0xFF007AFF)),
                        const SizedBox(width: 6),
                        Text(
                          selectedCircle.contains('Public') ? 'សាធារណៈ' : selectedCircle.split('/')[0].trim(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(CupertinoIcons.chevron_down, size: 12, color: CupertinoColors.systemGrey),
                      ],
                    ),
                  ),
                ),

                // Share to Story Toggle
                GestureDetector(
                  onTap: () => setState(() => _shareToStory = !_shareToStory),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _shareToStory ? const Color(0xFF007AFF).withOpacity(0.12) : AppTheme.fieldBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _shareToStory ? const Color(0xFF007AFF) : AppTheme.divider,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.camera,
                          size: 16,
                          color: _shareToStory ? const Color(0xFF007AFF) : AppTheme.secondaryText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _shareToStory ? 'ចែករំលែកទៅ Story' : 'Story: បិទ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _shareToStory ? const Color(0xFF007AFF) : AppTheme.secondaryText,
                          ),
                        ),
                      ],
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

  Widget _buildQuickPill({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF007AFF).withOpacity(0.12) : AppTheme.fieldBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF007AFF) : AppTheme.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? const Color(0xFF007AFF) : AppTheme.secondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? const Color(0xFF007AFF) : AppTheme.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 64,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF007AFF)),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
}
