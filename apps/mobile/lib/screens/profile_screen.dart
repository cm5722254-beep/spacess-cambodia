import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../models/post_model.dart';
import '../models/stream_model.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../utils/media_picker_helper.dart';
import '../widgets/post_card.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/media_image_view.dart';
import '../widgets/vip_subscription_sheet.dart';
import '../widgets/liquid_glass.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  bool hideMetrics = false;
  bool focusMode = false;
  int _selectedTab = 0; // 0: Settings, 1: My Posts, 2: Saved

  List<PostModel> _myPosts = [];
  List<PostModel> _savedPosts = [];
  List<StreamModel> _userStreams = [];
  bool _isLoadingPosts = false;
  bool _isLoadingStreams = false;

  @override
  void initState() {
    super.initState();
    _loadTabContent();
  }

  void _loadTabContent() async {
    if (_selectedTab == 1) {
      setState(() => _isLoadingPosts = true);
      final posts = await _api.fetchMyPosts();
      if (mounted) {
        setState(() {
          _myPosts = posts;
          _isLoadingPosts = false;
        });
      }
    } else if (_selectedTab == 2) {
      setState(() => _isLoadingPosts = true);
      final posts = await _api.fetchSavedPosts();
      if (mounted) {
        setState(() {
          _savedPosts = posts;
          _isLoadingPosts = false;
        });
      }
    } else if (_selectedTab == 3) {
      setState(() => _isLoadingStreams = true);
      final streams = await _api.fetchStreams(authorId: _api.currentUser?.id);
      if (mounted) {
        setState(() {
          _userStreams = streams;
          _isLoadingStreams = false;
        });
      }
    }
  }

  void _updateFocusMode(bool val) async {
    setState(() => focusMode = val);
    await _api.updateSettings(focusMode: val);
  }

  void _updateHideMetrics(bool val) async {
    setState(() => hideMetrics = val);
    await _api.updateSettings(hideMetrics: val);
  }

  void _confirmLogout() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(tr('ចាកចេញពីគណនី', 'Log Out')),
        content: Text(tr(
          'តើអ្នកពិតជាចង់ចាកចេញពីគណនី Spaces Cambodia មែនទេ?',
          'Are you sure you want to log out of Spaces Cambodia?',
        )),
        actions: [
          CupertinoDialogAction(
            child: Text(tr('បោះបង់', 'Cancel')),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(tr('ចាកចេញ', 'Log Out')),
            onPressed: () {
              Navigator.pop(ctx);
              _api.logout();
            },
          ),
        ],
      ),
    );
  }

  void _openChangePasswordDialog() {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool isChanging = false;

    showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: Text(tr('ផ្លាស់ប្តូរពាក្យសម្ងាត់', 'Change Password')),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                CupertinoTextField(
                  controller: oldPassCtrl,
                  placeholder: tr('ពាក្យសម្ងាត់បច្ចុប្បន្ន', 'Current Password'),
                  obscureText: true,
                  padding: const EdgeInsets.all(10),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: newPassCtrl,
                  placeholder: tr('ពាក្យសម្ងាត់ថ្មី (យ៉ាងហោច 6 តួ)', 'New Password (min 6 chars)'),
                  obscureText: true,
                  padding: const EdgeInsets.all(10),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: confirmPassCtrl,
                  placeholder: tr('បញ្ជាក់ពាក្យសម្ងាត់ថ្មី', 'Confirm New Password'),
                  obscureText: true,
                  padding: const EdgeInsets.all(10),
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: Text(tr('បោះបង់', 'Cancel')),
              onPressed: () => Navigator.pop(ctx),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: isChanging
                  ? null
                  : () async {
                      final oldPass = oldPassCtrl.text.trim();
                      final newPass = newPassCtrl.text.trim();
                      final confPass = confirmPassCtrl.text.trim();

                      if (oldPass.isEmpty || newPass.isEmpty) {
                        return;
                      }
                      if (newPass != confPass) {
                        return;
                      }

                      setDialogState(() => isChanging = true);
                      final ok = await _api.changePassword(oldPass, newPass);
                      if (mounted) {
                        Navigator.of(context, rootNavigator: true).pop();
                        showCupertinoDialog(
                          context: context,
                          builder: (alertCtx) => CupertinoAlertDialog(
                            title: Text(ok ? tr('ជោគជ័យ', 'Success') : tr('បរាជ័យ', 'Failed')),
                            content: Text(ok
                                ? tr('ពាក្យសម្ងាត់ត្រូវបានផ្លាស់ប្តូរដោយជោគជ័យ!', 'Password changed successfully!')
                                : tr('ពាក្យសម្ងាត់បច្ចុប្បន្នមិនត្រឹមត្រូវ', 'Incorrect current password')),
                            actions: [
                              CupertinoDialogAction(
                                child: Text(tr('យល់ព្រម', 'OK')),
                                onPressed: () => Navigator.pop(alertCtx),
                              ),
                            ],
                          ),
                        );
                      }
                    },
              child: Text(tr('រក្សាទុក', 'Save')),
            ),
          ],
        ),
      ),
    );
  }

  void _openChangeBannerSheet() async {
    final media = await MediaPickerHelper.pickAndUploadMedia(accept: 'image/*');
    if (media != null && media.isNotEmpty) {
      await _api.updateBanner(media);
      if (mounted) setState(() {});
    }
  }

  void _pickAndUploadAvatar() async {
    final media = await MediaPickerHelper.pickAndUploadMedia(accept: 'image/*');
    if (media != null && media.isNotEmpty) {
      await _api.updateProfile(avatar: media);
      if (mounted) setState(() {});
    }
  }

  void _openVipModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => VipSubscriptionSheet(
        onSubscribed: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  void _openEditProfileSheet() {
    final user = _api.currentUser;
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final bioCtrl = TextEditingController(text: user?.bio ?? '');
    final locationCtrl = TextEditingController(text: user?.location ?? 'Phnom Penh, Cambodia');
    final avatarCtrl = TextEditingController(text: user?.avatar ?? '');
    bool isSaving = false;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: AppTheme.modalBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text(tr('បោះបង់', 'Cancel')),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  Text(
                    tr('កែសម្រួលគណនី (Edit Profile)', 'Edit Profile'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryText),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            final updatedUser = await _api.updateProfile(
                              name: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : null,
                              bio: bioCtrl.text.trim().isNotEmpty ? bioCtrl.text.trim() : null,
                              location: locationCtrl.text.trim().isNotEmpty ? locationCtrl.text.trim() : null,
                              avatar: avatarCtrl.text.trim().isNotEmpty ? avatarCtrl.text.trim() : null,
                            );
                            if (mounted) {
                              setModalState(() => isSaving = false);
                              if (updatedUser != null) {
                                setState(() {});
                                Navigator.of(context, rootNavigator: true).pop();
                              } else {
                                showCupertinoDialog(
                                  context: context,
                                  builder: (dCtx) => CupertinoAlertDialog(
                                    title: Text(tr('ដំណឹងប្តូរឈ្មោះ', 'Update Notice')),
                                    content: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(tr(
                                        'លោកអ្នកអាចប្តូរឈ្មោះបានម្តងរៀងរាល់ ៧ ថ្ងៃ។ លេខសម្ងាត់អាចប្តូរបានគ្រប់ពេល។',
                                        'Name can only be changed once every 7 days. Password can be changed anytime.',
                                      )),
                                    ),
                                    actions: [
                                      CupertinoDialogAction(
                                        child: Text(tr('យល់ព្រម', 'OK')),
                                        onPressed: () => Navigator.of(dCtx).pop(),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            }
                          },
                    child: isSaving
                        ? const CupertinoActivityIndicator()
                        : Text(tr('រក្សាទុក', 'Save'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.2), width: 0.8),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.info_circle_fill, color: Color(0xFF007AFF), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr(
                                'ឈ្មោះអាចប្តូរបានម្តងរៀងរាល់ ៧ ថ្ងៃ។ លេខសម្ងាត់អាចប្តូរបានគ្រប់ពេល។',
                                'Name can be changed once every 7 days. Password can be changed anytime.',
                              ),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF007AFF)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(tr('ឈ្មោះពេញ (Full Name)', 'Full Name'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryText)),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: nameCtrl,
                      placeholder: tr('បញ្ចូលឈ្មោះពេញ', 'Enter full name'),
                      style: TextStyle(color: AppTheme.primaryText),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border, width: 0.6),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(tr('ជីវប្រវត្តិសង្ខេប (Bio)', 'Bio'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryText)),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: bioCtrl,
                      placeholder: tr('ពិពណ៌នាអំពីខ្លួនអ្នក...', 'Describe yourself...'),
                      maxLines: 3,
                      style: TextStyle(color: AppTheme.primaryText),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border, width: 0.6),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(tr('ទីតាំង (City / Location)', 'City / Location'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryText)),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: locationCtrl,
                      placeholder: tr('ឧ. ភ្នំពេញ, សៀមរាប, កំពត...', 'e.g. Phnom Penh, Siem Reap...'),
                      style: TextStyle(color: AppTheme.primaryText),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border, width: 0.6),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 1-Tap Pick Avatar from Phone
                    CupertinoButton(
                      color: const Color(0xFF007AFF).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: () async {
                        final liveUrl = await MediaPickerHelper.pickAndUploadMedia(accept: 'image/*');
                        if (liveUrl != null && liveUrl.isNotEmpty) {
                          avatarCtrl.text = liveUrl;
                          setModalState(() {});
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.camera_fill, size: 18, color: Color(0xFF007AFF)),
                          const SizedBox(width: 8),
                          Text(
                            tr('ជ្រើសរើសរូបពីទូរស័ព្ទ / ឧបករណ៍', 'Pick Avatar from Phone Gallery'),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF007AFF), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(tr('ឬ តំណភ្ជាប់រូបតំណាង (Or Avatar URL)', 'Or Avatar URL'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryText)),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: avatarCtrl,
                      placeholder: 'https://images.unsplash.com/...',
                      style: TextStyle(color: AppTheme.primaryText),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border, width: 0.6),
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
  }

  void _openStoreSettingsSheet() {
    final user = _api.currentUser;
    final storeNameCtrl = TextEditingController(
      text: (user?.storeName != null && user!.storeName!.isNotEmpty) ? user.storeName! : '${user?.name ?? "My"} Store',
    );
    final storePhoneCtrl = TextEditingController(
      text: (user?.storePhone != null && user!.storePhone!.isNotEmpty) ? user.storePhone! : (user?.phone ?? ''),
    );
    final bakongIdCtrl = TextEditingController(text: user?.bakongAccountId ?? '');
    final storeDescCtrl = TextEditingController(text: user?.storeDescription ?? '');

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
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
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr('កំណត់ហាង & Bakong Payway', 'Store & Bakong Settings'),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text(tr('រក្សាទុក', 'Save'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final updated = await _api.updateStore(
                        storeName: storeNameCtrl.text.trim(),
                        storePhone: storePhoneCtrl.text.trim(),
                        storeDescription: storeDescCtrl.text.trim(),
                        bakongAccountId: bakongIdCtrl.text.trim(),
                      );
                      if (updated != null && mounted) {
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
              Container(height: 0.5, color: AppTheme.divider),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1251B).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE1251B).withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.qrcode_viewfinder, color: Color(0xFFE1251B), size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tr(
                                'អតិថិជននឹងស្កេនទូទាត់ប្រាក់ចូលគណនី Bakong របស់អ្នកដោយស្វ័យប្រវត្តិតាមរយៈ Bakong KHQR!',
                                'Buyers can scan and pay directly into your Bakong account via Bakong KHQR!',
                              ),
                              style: const TextStyle(fontSize: 12, color: Color(0xFFE1251B), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(tr('ឈ្មោះហាងអនឡាញ (Store Name):', 'Store Name:'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryText)),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: storeNameCtrl,
                      placeholder: 'ឧ. Davit Tech Store',
                      style: TextStyle(color: AppTheme.primaryText),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border, width: 0.6),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(tr('Bakong Account ID (គណនីបាគងផ្ទាល់ខ្លួន):', 'Your Bakong Account ID:'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryText)),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: bakongIdCtrl,
                      placeholder: 'ឧ. username@bkrt (NBC Bakong ID)',
                      style: TextStyle(color: AppTheme.primaryText),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border, width: 0.6),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(tr('លេខទូរស័ព្ទទំនាក់ទំនងហាង (Store Phone):', 'Store Phone:'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryText)),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: storePhoneCtrl,
                      placeholder: '012 345 678',
                      style: TextStyle(color: AppTheme.primaryText),
                      keyboardType: TextInputType.phone,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border, width: 0.6),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(tr('ការពិពណ៌នាអំពីហាង (Description):', 'Store Description:'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryText)),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: storeDescCtrl,
                      placeholder: tr('លក់ផលិតផលគុណភាពខ្ពស់...', 'Selling quality gadgets...'),
                      maxLines: 3,
                      style: TextStyle(color: AppTheme.primaryText),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border, width: 0.6),
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
  }

  void _openComments(PostModel post) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CommentsSheet(post: post),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _api.isDarkModeNotifier,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: LanguageService().languageNotifier,
          builder: (context, currentLang, _) {
            final user = _api.currentUser;
            final isAdmin = user?.isAdmin ?? false;
            final rawName = user?.name.trim() ?? '';
            final userName = rawName.isNotEmpty ? rawName : (isAdmin ? 'CHAN SOCHEAT' : 'អ្នកប្រើប្រាស់');
            final rawHandle = user?.username.trim() ?? '';
            final userHandle = rawHandle.isNotEmpty ? rawHandle : (isAdmin ? 'admin' : 'user');
            final rawPhone = user?.phone.trim() ?? '';
            final userPhone = rawPhone.isNotEmpty ? rawPhone : '';
            final userAvatar = (user?.avatar != null && user!.avatar.isNotEmpty)
                ? user.avatar
                : (isAdmin
                    ? '/uploads/admin_avatar.jpg'
                    : '/default_avatar.svg');
            final userBanner = user?.bannerUrl ??
                'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=1200&q=80';

            return CupertinoPageScaffold(
      backgroundColor: AppTheme.scaffoldBg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppTheme.navBarBg,
        middle: Text(
          tr('គណនី និងការកំណត់', 'Profile & Settings'),
          style: TextStyle(color: AppTheme.primaryText, fontWeight: FontWeight.w700),
        ),
        trailing: LiquidGlassPressable(
          onTap: () => LanguageService().toggleLanguage(),
          child: LiquidGlassContainer(
            borderRadius: 14,
            blurSigma: 14,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.globe, size: 14, color: AppTheme.accentBlue),
                const SizedBox(width: 4),
                Text(
                  LanguageService().isKhmer ? 'EN' : 'ខ្មែរ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentBlue),
                ),
              ],
            ),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            ResponsiveLayout.horizontalPadding(context),
            12,
            ResponsiveLayout.horizontalPadding(context),
            ResponsiveLayout.bottomDockClearance(context),
          ),
          children: [
            // User Header Profile Card with Cover Banner (Liquid Glass)
            LiquidGlassContainer(
              borderRadius: 24,
              blurSigma: 20,
              child: Column(
                children: [
                  // Cover Banner Photo
                  Stack(
                    children: [
                      MediaImageView(
                        url: userBanner,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      // Gradient overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                            ),
                          ),
                        ),
                      ),
                      // Change Banner Button
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: _openChangeBannerSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xCC000000),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.camera_fill, size: 14, color: CupertinoColors.white),
                                const SizedBox(width: 4),
                                Text(
                                  tr('ប្ដូរ Banner', 'Banner'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Avatar & User Details
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -35),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Avatar with border and 1-tap change camera badge
                              GestureDetector(
                                onTap: _pickAndUploadAvatar,
                                child: Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cardBg,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(35),
                                        child: MediaImageView(
                                          url: userAvatar,
                                          width: 70,
                                          height: 70,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF007AFF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(CupertinoIcons.camera_fill, size: 12, color: CupertinoColors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              userName,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.primaryText,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (user?.isVerified ?? false) ...[
                                            const SizedBox(width: 5),
                                            const Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFF007AFF), size: 18),
                                          ],

                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        userPhone.isNotEmpty ? '@$userHandle • $userPhone' : '@$userHandle',
                                        style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action Buttons: Edit Profile & VIP Upgrade
                        Row(
                          children: [
                            Expanded(
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                color: AppTheme.surfaceBg,
                                borderRadius: BorderRadius.circular(12),
                                onPressed: _openEditProfileSheet,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(CupertinoIcons.pencil, size: 16, color: Color(0xFF007AFF)),
                                    const SizedBox(width: 6),
                                    Text(
                                      tr('កែសម្រួល', 'Edit Profile'),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF007AFF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                color: const Color(0xFFFFB800).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                onPressed: _openVipModal,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(CupertinoIcons.rosette, size: 16, color: Color(0xFFFFB800)),
                                    const SizedBox(width: 6),
                                    Text(
                                      user?.isVip ?? false
                                          ? (user?.isUltra ?? false ? 'Ultra VIP' : 'Pro+ VIP')
                                          : tr('ដំឡើង VIP', 'VIP Club'),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFFFB800),
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
            ),
            const SizedBox(height: 18),

            // Liquid Glass Sliding Profile Segmented Control Tabs
            LiquidGlassSegmentControl<int>(
              groupValue: _selectedTab,
              items: [
                LiquidGlassSegmentItem(
                  value: 0,
                  label: tr('ការកំណត់', 'Settings'),
                  icon: CupertinoIcons.slider_horizontal_3,
                ),
                LiquidGlassSegmentItem(
                  value: 1,
                  label: tr('ផុសរបស់ខ្ញុំ', 'Posts'),
                  icon: CupertinoIcons.square_grid_2x2,
                ),
                LiquidGlassSegmentItem(
                  value: 2,
                  label: tr('រក្សាទុក', 'Saved'),
                  icon: CupertinoIcons.bookmark,
                ),
                LiquidGlassSegmentItem(
                  value: 3,
                  label: tr('វីដេអូ', 'Videos'),
                  icon: CupertinoIcons.play_rectangle,
                ),
              ],
              onValueChanged: (val) {
                setState(() => _selectedTab = val);
                _loadTabContent();
              },
            ),
            const SizedBox(height: 18),

            // Tab 1: My Posts
            if (_selectedTab == 1) ...[
              if (_isLoadingPosts)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CupertinoActivityIndicator(radius: 14),
                  ),
                )
              else if (_myPosts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border, width: 0.6),
                  ),
                  child: Column(
                    children: [
                      const Icon(CupertinoIcons.square_pencil, size: 40, color: CupertinoColors.systemGrey3),
                      const SizedBox(height: 12),
                      Text(
                        tr(
                          'មិនទាន់មានការបង្ហោះនៅឡើយទេ\nចែករំលែករឿងរ៉ាវដំបូងរបស់អ្នកឥឡូវនេះ!',
                          'No posts yet.\nShare your first story today!',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.secondaryText, height: 1.4),
                      ),
                    ],
                  ),
                )
              else
                ..._myPosts.map(
                  (post) => PostCard(
                    post: post,
                    onCommentTap: () => _openComments(post),
                    onPostDeleted: _loadTabContent,
                    onPostUpdated: _loadTabContent,
                  ),
                ),
            ],

            // Tab 2: Saved Posts
            if (_selectedTab == 2) ...[
              if (_isLoadingPosts)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CupertinoActivityIndicator(radius: 14),
                  ),
                )
              else if (_savedPosts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border, width: 0.6),
                  ),
                  child: Column(
                    children: [
                      const Icon(CupertinoIcons.bookmark, size: 40, color: CupertinoColors.systemGrey3),
                      const SizedBox(height: 12),
                      Text(
                        tr(
                          'មិនទាន់មានការបង្ហោះដែលបានរក្សាទុកទេ\nចុច Bookmark លើការបង្ហោះដែលអ្នកចូលចិត្ត!',
                          'No saved posts yet.\nBookmark posts to view them here!',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.secondaryText, height: 1.4),
                      ),
                    ],
                  ),
                )
              else
                ..._savedPosts.map(
                  (post) => PostCard(
                    post: post,
                    onCommentTap: () => _openComments(post),
                    onPostDeleted: _loadTabContent,
                    onPostUpdated: _loadTabContent,
                  ),
                ),
            ],

            // Tab 3: Videos & Streams
            if (_selectedTab == 3) ...[
              if (_isLoadingStreams)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CupertinoActivityIndicator(radius: 14),
                  ),
                )
              else if (_userStreams.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border, width: 0.6),
                  ),
                  child: Column(
                    children: [
                      const Icon(CupertinoIcons.play_rectangle, size: 40, color: CupertinoColors.systemGrey3),
                      const SizedBox(height: 12),
                      Text(
                        tr(
                          'មិនទាន់មានវីដេអូ ឬការផ្សាយផ្ទាល់នៅឡើយទេ\nបង្ហោះវីដេអូរបស់អ្នកឥឡូវនេះ!',
                          'No videos or streams published yet.\nUpload your video now!',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.secondaryText, height: 1.4),
                      ),
                    ],
                  ),
                )
              else
                ..._userStreams.map(
                  (stream) => Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                MediaImageView(url: stream.thumbnailUrl ?? stream.videoUrl, fit: BoxFit.cover),
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                                  child: const Icon(CupertinoIcons.play_fill, color: CupertinoColors.white, size: 22),
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(4)),
                                    child: Text(stream.duration, style: const TextStyle(color: CupertinoColors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(stream.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primaryText)),
                        const SizedBox(height: 4),
                        Text('• ${stream.viewsCount} views  • ${stream.likesCount} likes', style: TextStyle(fontSize: 11, color: AppTheme.secondaryText)),
                      ],
                    ),
                  ),
                ),
            ],

            // Tab 0: Settings & Administration
            if (_selectedTab == 0) ...[
              // Features & Store Section
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 8),
                child: Text(
                  tr('មុខងារពិសេស និងហាង (FEATURES & STORE)', 'STORE & EXPERIENCE'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondaryText,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border, width: 0.8),
                ),
                child: Column(
                  children: [
                    // Online Store & Bakong
                    CupertinoListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1251B).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(CupertinoIcons.bag_fill, color: Color(0xFFE1251B), size: 20),
                      ),
                      title: Text(
                        tr('ហាងអនឡាញ & Bakong Payway', 'Online Store & Bakong Payway'),
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryText),
                      ),
                      subtitle: Text(
                        '${(user?.storeName != null && user!.storeName!.isNotEmpty) ? user.storeName! : tr("មិនទាន់កំណត់ហាង", "Store not set")} • ${(user?.bakongAccountId != null && user!.bakongAccountId!.isNotEmpty) ? user.bakongAccountId! : tr("សូមដាក់គណនីបាគង", "Set Bakong ID")}',
                        style: TextStyle(color: AppTheme.secondaryText),
                      ),
                      trailing: const Icon(CupertinoIcons.chevron_right, size: 18, color: CupertinoColors.systemGrey3),
                      onTap: _openStoreSettingsSheet,
                    ),
                    Container(height: 0.5, color: AppTheme.divider),

                    // Night Mode / OLED Pitch Black Dark Theme Switch
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5856D6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(CupertinoIcons.moon_stars_fill, color: Color(0xFF5856D6), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('មុខងាររាត្រី (Night Mode / OLED Dark)', 'OLED Night Mode'),
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.primaryText),
                                ),
                                Text(
                                  tr('ប្ដូរផ្ទៃក្រោយខ្មៅងងឹត ការពារភ្នែក និងសន្សំថ្ម', 'Deep pitch-black UI saving battery'),
                                  style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                                ),
                              ],
                            ),
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable: _api.isDarkModeNotifier,
                            builder: (context, isDark, _) {
                              return CupertinoSwitch(
                                value: isDark,
                                activeColor: const Color(0xFF5856D6),
                                onChanged: (val) {
                                  _api.setThemeMode(val);
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(height: 0.5, color: AppTheme.divider),

                    // Focus Mode Switch
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF34C759).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(CupertinoIcons.leaf_arrow_circlepath, color: Color(0xFF34C759), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('Focus Mode (Calm Digest)', 'Focus Mode (Calm Digest)'),
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.primaryText),
                                ),
                                Text(
                                  tr('គ្មាន Infinite scroll, មានតែ Digest ប្រចាំថ្ងៃ', 'No infinite scroll, daily summary only'),
                                  style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                                ),
                              ],
                            ),
                          ),
                          CupertinoSwitch(
                            value: focusMode,
                            activeColor: const Color(0xFF34C759),
                            onChanged: _updateFocusMode,
                          ),
                        ],
                      ),
                    ),
                    Container(height: 0.5, color: AppTheme.divider),

                    // Hide Metrics Switch
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF2D55).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(CupertinoIcons.heart_slash, color: Color(0xFFFF2D55), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('លាក់ចំនួន Like (Hide Metrics)', 'Hide Like Counts'),
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.primaryText),
                                ),
                                Text(
                                  tr('កាត់បន្ថយសម្ពាធសង្គម មិនបង្ហាញចំនួន Like', 'Eliminates social vanity pressure'),
                                  style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                                ),
                              ],
                            ),
                          ),
                          CupertinoSwitch(
                            value: hideMetrics,
                            activeColor: const Color(0xFF007AFF),
                            onChanged: _updateHideMetrics,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Security & Privacy Section
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 8),
                child: Text(
                  tr('សុវត្ថិភាព និងភាពឯកជន (SECURITY & PRIVACY)', 'SECURITY & PRIVACY'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondaryText,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border, width: 0.8),
                ),
                child: Column(
                  children: [
                    // Change Password
                    CupertinoListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(CupertinoIcons.lock_shield, color: Color(0xFF007AFF), size: 20),
                      ),
                      title: Text(
                        tr('ប្តូរពាក្យសម្ងាត់ (Change Password)', 'Change Password'),
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryText),
                      ),
                      subtitle: Text(
                        tr('ការពារគណនីរបស់អ្នកជាមួយលេខសម្ងាត់ថ្មី', 'Update password securely'),
                        style: TextStyle(color: AppTheme.secondaryText),
                      ),
                      trailing: const Icon(CupertinoIcons.chevron_right, size: 18, color: CupertinoColors.systemGrey3),
                      onTap: _openChangePasswordDialog,
                    ),
                    Container(height: 0.5, color: AppTheme.divider),

                    // Two-Factor Authentication Switch
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF34C759).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(CupertinoIcons.shield_lefthalf_fill, color: Color(0xFF34C759), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('ការផ្ទៀងផ្ទាត់ 2-Factor (2FA)', 'Two-Factor Authentication (2FA)'),
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.primaryText),
                                ),
                                Text(
                                  tr('បន្ថែមស្រទាប់សុវត្ថិភាពខ្ពស់បំផុតលើគណនី', 'Extra security layer for your account'),
                                  style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                                ),
                              ],
                            ),
                          ),
                          CupertinoSwitch(
                            value: user?.twoFactorEnabled ?? false,
                            activeColor: const Color(0xFF34C759),
                            onChanged: (val) async {
                              await _api.toggleTwoFactor();
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(height: 0.5, color: AppTheme.divider),

                    // Language Switcher Tile
                    CupertinoListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5856D6).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(CupertinoIcons.globe, color: Color(0xFF5856D6), size: 20),
                      ),
                      title: Text(
                        tr('ប្ដូរភាសា (Language)', 'Language (ភាសា)'),
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryText),
                      ),
                      subtitle: Text(
                        LanguageService().isKhmer ? 'ភាសាខ្មែរ (Khmer)' : 'English',
                        style: TextStyle(color: AppTheme.secondaryText),
                      ),
                      trailing: Text(
                        LanguageService().isKhmer ? 'Switch to EN' : 'ប្ដូរទៅ ខ្មែរ',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF007AFF)),
                      ),
                      onTap: () {
                        LanguageService().toggleLanguage();
                      },
                    ),
                    Container(height: 0.5, color: AppTheme.divider),

                    // Log Out
                    CupertinoListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(CupertinoIcons.arrow_right_square, color: Color(0xFFFF3B30), size: 20),
                      ),
                      title: Text(
                        tr('ចាកចេញពីគណនី (Log Out)', 'Log Out'),
                        style: const TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        tr('ចេញពីគណនីបច្ចុប្បន្នលើឧបករណ៍នេះ', 'Log out of current session'),
                        style: TextStyle(color: AppTheme.secondaryText),
                      ),
                      trailing: const Icon(CupertinoIcons.chevron_right, size: 18, color: CupertinoColors.systemGrey3),
                      onTap: _confirmLogout,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Firebase Cloud Integration Section
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 8),
                child: Text(
                  tr('ការតភ្ជាប់ FIREBASE (FIREBASE CLOUD INTEGRATION)', 'FIREBASE CLOUD INTEGRATION'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF9500),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border, width: 0.8),
                ),
                child: CupertinoListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(CupertinoIcons.flame_fill, color: Color(0xFFFF9500), size: 20),
                  ),
                  title: Text(
                    'Firebase Cloud Messaging (FCM)',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryText),
                  ),
                  subtitle: Text(
                    tr('បានភ្ជាប់ជោគជ័យ (Status: Connected / Active)', 'Status: Connected / Active'),
                    style: TextStyle(color: AppTheme.secondaryText),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ONLINE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF34C759)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
          },
        );
      },
    );
  }
}
