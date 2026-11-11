import 'package:flutter/cupertino.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../utils/media_picker_helper.dart';
import 'liquid_glass.dart';
import 'media_image_view.dart';

class CreatePostSheet extends StatefulWidget {
  final List<SpaceModel> spaces;
  final Function(PostModel newPost) onPostCreated;

  const CreatePostSheet({
    super.key,
    required this.spaces,
    required this.onPostCreated,
  });

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  late String selectedSpaceId;
  String selectedCircle = 'Public / សាធារណៈ';
  String selectedCity = 'Phnom Penh, Cambodia';
  bool isSubmitting = false;
  bool isImporting = false;
  String? _importedMedia;

  final List<String> circles = [
    'Public / សាធារណៈ',
    'Close Friends / មិត្តជិតស្និទ្ធ',
    'Family Only / គ្រួសារតែប៉ុណ្ណោះ',
    'Team Members / សហការី',
  ];

  final List<String> cambodiaCities = [
    'Phnom Penh, Cambodia',
    'Siem Reap, Cambodia',
    'Kampot, Cambodia',
    'Battambang, Cambodia',
    'Sihanoukville, Cambodia',
    'Kep Beach, Cambodia',
  ];

  @override
  void initState() {
    super.initState();
    selectedSpaceId = widget.spaces.isNotEmpty ? widget.spaces.first.id : 'space-public-1';
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
        }
      });
    }
  }

  void _submit() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) return;

    setState(() => isSubmitting = true);

    final finalMedia = _importedMedia ?? (_imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim());

    final newPost = await ApiService().createPost(
      content: text,
      spaceId: selectedSpaceId,
      city: selectedCity,
      circleName: selectedCircle,
      imageUrl: finalMedia,
      tags: ['SpacesCambodia', 'NewPost'],
    );

    setState(() => isSubmitting = false);

    if (newPost != null && mounted) {
      widget.onPostCreated(newPost);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppTheme.modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header: Cancel & Post button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Text(tr('បោះបង់', 'Cancel')),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                tr('បង្កើតការបង្ហោះថ្មី', 'Create Post'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryText,
                ),
              ),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                borderRadius: BorderRadius.circular(20),
                onPressed: isSubmitting ? null : _submit,
                child: isSubmitting
                    ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                    : Text(
                        tr('បង្ហោះ', 'Post'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Space Selector
          Text(
            tr('ជ្រើសរើស Space:', 'Select Space:'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.spaces.map((space) {
                final isSelected = selectedSpaceId == space.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    color: isSelected ? const Color(0xFF007AFF) : AppTheme.surfaceBg,
                    borderRadius: BorderRadius.circular(16),
                    onPressed: () {
                      setState(() {
                        selectedSpaceId = space.id;
                      });
                    },
                    child: Text(
                      space.khmerName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? CupertinoColors.white : AppTheme.primaryText,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // City / Location Selector
          Text(
            tr('ទីតាំង / ទីក្រុង (City / Location):', 'City / Location:'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: cambodiaCities.map((city) {
                final isSelected = selectedCity == city;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: LiquidGlassPill(
                    label: city,
                    icon: CupertinoIcons.location_solid,
                    isSelected: isSelected,
                    activeColor: const Color(0xFF34C759),
                    onTap: () {
                      setState(() {
                        selectedCity = city;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Audience Circle Selector
          Text(
            tr('អ្នកមើល (Audience Circle):', 'Audience Circle:'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: circles.map((circle) {
                final isSelected = selectedCircle == circle;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: LiquidGlassPill(
                    label: circle,
                    isSelected: isSelected,
                    activeColor: const Color(0xFFAF52DE),
                    onTap: () {
                      setState(() {
                        selectedCircle = circle;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Text Field for Post
          Expanded(
            child: CupertinoTextField(
              controller: _contentController,
              placeholder: tr(
                'ចែករំលែករឿងរ៉ាវ ការងារ ឬរូបភាពរបស់អ្នកនៅទីនេះ...',
                'Share your story, work, or thoughts here...',
              ),
              maxLines: null,
              expands: true,
              style: TextStyle(color: AppTheme.primaryText),
              textAlignVertical: TextAlignVertical.top,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.fieldBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border, width: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Import Photo from Phone / Device
          if (_importedMedia != null)
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: MediaImageView(url: _importedMedia!, width: 50, height: 50, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('បានជ្រើសរើសរូបភាពពីទូរស័ព្ទ', 'Photo imported from device'),
                    style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.xmark_circle_fill, color: CupertinoColors.systemGrey3),
                  onPressed: () => setState(() {
                    _importedMedia = null;
                    _imageUrlController.clear();
                  }),
                ),
              ],
            )
          else
            LiquidGlassButton(
              label: tr('ជ្រើសរើសរូបភាព / វីដេអូពីទូរស័ព្ទ', 'Import Media from Device'),
              icon: CupertinoIcons.photo_on_rectangle,
              variant: LiquidButtonVariant.neutral,
              expand: true,
              isLoading: isImporting,
              onPressed: isImporting ? null : _pickFromDevice,
            ),
        ],
      ),
    );
  }
}
