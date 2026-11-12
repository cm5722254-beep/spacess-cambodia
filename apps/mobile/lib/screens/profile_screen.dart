import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../models/post_model.dart';
import '../models/stream_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/realtime_service.dart';
import '../services/theme_service.dart';
import '../utils/media_picker_helper.dart';
import '../widgets/post_card.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/create_post_sheet.dart';
import '../widgets/create_reel_sheet.dart';
import '../widgets/media_image_view.dart';
import '../widgets/vip_subscription_sheet.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/pwa_install_sheet.dart';
import '../widgets/media_cropper_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  bool hideMetrics = false;
  bool focusMode = false;
  int _selectedTab = 1; // 1: My Posts (Default), 3: Videos, 2: Saved
  bool _isPageMode = false;

  List<PostModel> _myPosts = [];
  List<PostModel> _savedPosts = [];
  List<PostModel> _likedPosts = [];
  List<StreamModel> _myStreams = [];
  bool _isLoadingPosts = false;
  int _followerCount = 0;
  int _followingCount = 0;
  double _bakongSalesTotalUsd = 0.0;
  int _paidSalesCount = 0;
  List<PublicUserModel> _realFriends = [];

  @override
  void initState() {
    super.initState();
    _loadTabContent();
    _loadUserStats();
  }

  void _loadUserStats() async {
    final user = _api.currentUser;
    if (user != null) {
      final profile = await _api.fetchPublicProfile(user.id);
      final friendsOverview = await _api.fetchFriendsOverview();
      final orders = await _api.fetchUserOrders();
      final List rawSales = (orders['sales'] is List) ? orders['sales'] : [];
      double salesUsd = 0.0;
      int paidCount = 0;
      for (final o in rawSales) {
        if (o is Map && o['status'] == 'PAID') {
          paidCount++;
          final amt = o['amount'];
          final cur = o['currency']?.toString().toUpperCase() ?? 'USD';
          if (amt is num) {
            salesUsd += (cur == 'KHR') ? (amt.toDouble() / 4100.0) : amt.toDouble();
          }
        }
      }
      if (mounted) {
        setState(() {
          _followerCount = profile?['followerCount'] ?? 0;
          _followingCount = profile?['followingCount'] ?? 0;
          _realFriends = friendsOverview['friends'] ?? [];
          _bakongSalesTotalUsd = salesUsd;
          _paidSalesCount = paidCount;
        });
      }
    }
  }

  void _loadTabContent() async {
    if (_selectedTab == 1 || _selectedTab == 2 || _selectedTab == 3) {
      setState(() => _isLoadingPosts = true);
      final posts = await _api.fetchMyPosts();
      if (mounted) {
        setState(() {
          _myPosts = posts;
          _isLoadingPosts = false;
        });
      }
    } else if (_selectedTab == 4) {
      setState(() => _isLoadingPosts = true);
      final streams = await _api.fetchStreams(authorId: _api.currentUser?.id);
      if (mounted) {
        setState(() {
          _myStreams = streams;
          _isLoadingPosts = false;
        });
      }
    } else if (_selectedTab == 5) {
      setState(() => _isLoadingPosts = true);
      final posts = await _api.fetchSavedPosts();
      if (mounted) {
        setState(() {
          _savedPosts = posts;
          _isLoadingPosts = false;
        });
      }
    } else if (_selectedTab == 6) {
      setState(() => _isLoadingPosts = true);
      final feed = await _api.fetchFeed();
      if (mounted) {
        setState(() {
          _likedPosts = feed.where((p) => p.isLiked).toList();
          _isLoadingPosts = false;
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
    if (media != null && media.isNotEmpty && mounted) {
      final cropped = await MediaCropperSheet.show(
        context,
        imageUrl: media,
        isCircle: false,
        title: 'កែសម្រួលរូប Banner (Crop & Position)',
      );
      if (cropped != null) {
        await _api.updateBanner(cropped);
        if (mounted) setState(() {});
      }
    }
  }

  void _pickAndUploadAvatar() async {
    final media = await MediaPickerHelper.pickAndUploadMedia(accept: 'image/*');
    if (media != null && media.isNotEmpty && mounted) {
      final cropped = await MediaCropperSheet.show(
        context,
        imageUrl: media,
        isCircle: true,
        title: 'កែសម្រួលរូប Profile (Crop & Zoom)',
      );
      if (cropped != null) {
        await _api.updateProfile(avatar: cropped);
        if (mounted) setState(() {});
      }
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
    final emailCtrl = TextEditingController(text: user?.email ?? '');
    final bioCtrl = TextEditingController(text: user?.bio ?? '');
    final locationCtrl = TextEditingController(text: user?.location ?? 'Phnom Penh, Cambodia');
    final avatarCtrl = TextEditingController(text: user?.avatar ?? '');
    bool isSaving = false;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.88,
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
                              email: emailCtrl.text.trim(),
                              bio: bioCtrl.text.trim(),
                              location: locationCtrl.text.trim().isNotEmpty ? locationCtrl.text.trim() : null,
                              avatar: avatarCtrl.text.trim().isNotEmpty ? avatarCtrl.text.trim() : null,
                            );
                            if (mounted) {
                              setModalState(() => isSaving = false);
                              if (updatedUser != null) {
                                setState(() {});
                                Navigator.of(context, rootNavigator: true).pop();
                              } else {
                                final errText = _api.lastErrorMessage ??
                                    tr(
                                      'លោកអ្នកអាចប្តូរឈ្មោះបានម្តងរៀងរាល់ ៧ ថ្ងៃ ឬអ៊ីមែលមិនត្រឹមត្រូវ។',
                                      'Name can only be changed every 7 days or email is invalid/in use.',
                                    );
                                showCupertinoDialog(
                                  context: context,
                                  builder: (dCtx) => CupertinoAlertDialog(
                                    title: Text(tr('ដំណឹងកែសម្រួល', 'Update Notice')),
                                    content: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(errText),
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
              const SizedBox(height: 14),
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
                                'ឈ្មោះអាចប្តូរបានម្តងរៀងរាល់ ៧ ថ្ងៃ។ Bio, អាសយដ្ឋាន, Email & Password ប្តូរបានគ្រប់ពេល។',
                                'Name can be changed every 7 days. Bio, Address, Email & Password anytime.',
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

                    Text(tr('អ៊ីមែល (Email)', 'Email Address'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryText)),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      placeholder: 'name@example.com',
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

                    Text(tr('អាសយដ្ឋាន (Address / Location)', 'Address / Location'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryText)),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: locationCtrl,
                      placeholder: tr('ឧ. ផ្ទះលេខ..., ភ្នំពេញ, សៀមរាប...', 'e.g. Street..., Phnom Penh...'),
                      style: TextStyle(color: AppTheme.primaryText),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border, width: 0.6),
                      ),
                    ),
                    const SizedBox(height: 14),

                    CupertinoButton(
                      color: const Color(0xFFFF9500).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openChangePasswordDialog();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.lock_shield_fill, size: 17, color: Color(0xFFFF9500)),
                          const SizedBox(width: 8),
                          Text(
                            tr('ប្តូរពាក្យសម្ងាត់ (Change Password)', 'Change Password'),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFFF9500), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

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
                      placeholder: 'https://...',
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

  void _showAccountOrPageSwitcher() {
    final user = _api.currentUser;
    final hasStore = user?.storeName != null && user!.storeName!.trim().isNotEmpty;
    final storeTitle = hasStore ? user.storeName!.trim() : 'បង្កើតទំព័រអាជីវកម្ម (Create Business Page)';

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('ប្តូរគណនី / ទំព័រ (Switch Profile / Page)', style: TextStyle(fontWeight: FontWeight.bold)),
        message: const Text('អ្នកអាចប្តូររវាងគណនីផ្ទាល់ខ្លួន និងទំព័រអាជីវកម្ម (Business Page 1 គណនី)'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: !_isPageMode,
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isPageMode = false);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.person_crop_circle_fill, size: 18),
                const SizedBox(width: 8),
                Text('គណនីផ្ទាល់ខ្លួន: ${user?.name ?? "User"}'),
                if (!_isPageMode) ...[
                  const SizedBox(width: 6),
                  const Icon(CupertinoIcons.checkmark, size: 16, color: Color(0xFF007AFF)),
                ],
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _isPageMode,
            onPressed: () {
              Navigator.pop(ctx);
              if (!hasStore) {
                _openStoreSettingsSheet();
              } else {
                setState(() => _isPageMode = true);
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.flag_fill, size: 18, color: Color(0xFF007AFF)),
                const SizedBox(width: 8),
                Text('ទំព័រអាជីវកម្ម: $storeTitle'),
                if (_isPageMode) ...[
                  const SizedBox(width: 6),
                  const Icon(CupertinoIcons.checkmark, size: 16, color: Color(0xFF007AFF)),
                ],
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('បិទ'),
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
    final storeTaglineCtrl = TextEditingController(text: user?.storeTagline ?? '');
    final storeBannerCtrl = TextEditingController(text: user?.storeBannerUrl ?? '');
    String selectedColor = (user?.storeThemeColor != null && user!.storeThemeColor!.isNotEmpty)
        ? user.storeThemeColor!
        : '#0A84FF';

    const themeColors = [
      '#0A84FF',
      '#34C759',
      '#FF6B00',
      '#AF52DE',
      '#D97706',
      '#E1251B',
    ];

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.88,
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
                      tr('តុបតែងហាង & Bakong Payway', 'Decorate Store & Bakong'),
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
                          storeTagline: storeTaglineCtrl.text.trim(),
                          storeBannerUrl: storeBannerCtrl.text.trim(),
                          storeThemeColor: selectedColor,
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
                                  'អតិថិជននឹងឃើញការតុបតែងហាងស្អាតៗ និងស្កេន Bakong KHQR ចូលគណនីអ្នកផ្ទាល់!',
                                  'Buyers see your decorated storefront and pay directly via Bakong KHQR!',
                                ),
                                style: const TextStyle(fontSize: 12, color: Color(0xFFE1251B), height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(tr('ពណ៌តុបតែងហាង (Store Theme Color):', 'Store Theme Color:'),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryText)),
                      const SizedBox(height: 8),
                      Row(
                        children: themeColors.map((hex) {
                          final col = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                          final isSel = selectedColor == hex;
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedColor = hex),
                            child: Container(
                              width: 32,
                              height: 32,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                                border: isSel
                                    ? Border.all(color: AppTheme.primaryText, width: 2.5)
                                    : null,
                              ),
                              child: isSel
                                  ? const Icon(CupertinoIcons.checkmark, color: CupertinoColors.white, size: 16)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Text(tr('Banner រូបភាពហាង (Store Banner):', 'Store Banner Photo:'),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryText)),
                      const SizedBox(height: 6),
                      if (storeBannerCtrl.text.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: MediaImageView(
                            url: storeBannerCtrl.text,
                            height: 95,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      CupertinoButton(
                        color: const Color(0xFF0A84FF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        onPressed: () async {
                          final url = await MediaPickerHelper.pickAndUploadMedia(accept: 'image/*');
                          if (url != null && url.isNotEmpty) {
                            storeBannerCtrl.text = url;
                            setModalState(() {});
                          }
                        },
                        child: Text(
                          tr('ជ្រើសរើស Banner ហាងពីទូរស័ព្ទ', 'Pick Store Banner Photo'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0A84FF)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(tr('ពាក្យស្លោកហាង (Store Tagline):', 'Store Tagline:'),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryText)),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: storeTaglineCtrl,
                        placeholder: tr('ឧ. ធានាគុណភាព 100% ដឹកជញ្ជូនរហ័ស', 'e.g. Authentic quality, fast delivery'),
                        style: TextStyle(color: AppTheme.primaryText),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.fieldBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border, width: 0.6),
                        ),
                      ),
                      const SizedBox(height: 14),
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
      ),
    );
  }

  void _openStoryArchiveSheet() async {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return FutureBuilder<List<StoryModel>>(
          future: _api.fetchStoryArchive(),
          builder: (ctx, snap) {
            final items = snap.data ?? [];
            return LiquidGlassSheet(
              initialHeightFraction: 0.82,
              child: Column(
                children: [
                  Text(
                    tr('ប្រវត្តិ Story (Story Archive 24h)', 'Story History & Archive (24h)'),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.primaryText),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'Story នឹងបាត់ពី Feed បន្ទាប់ពី 24 ម៉ោង ប៉ុន្តែនៅរក្សាទុកក្នុងប្រវត្តិផ្ទាល់ខ្លួនរបស់អ្នក។',
                      'Stories expire from active feeds after 24 hours and stay archived here.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: snap.connectionState == ConnectionState.waiting
                        ? const Center(child: CupertinoActivityIndicator())
                        : items.isEmpty
                            ? Center(
                                child: Text(
                                  tr('មិនទាន់មានប្រវត្តិ Story ទេ', 'No archived stories yet'),
                                  style: TextStyle(color: AppTheme.secondaryText),
                                ),
                              )
                            : StatefulBuilder(
                                builder: (ctx, setArchState) => ListView.builder(
                                  itemCount: items.length,
                                  itemBuilder: (c, idx) {
                                    final st = items[idx];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cardBg,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppTheme.border, width: 0.6),
                                      ),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: MediaImageView(
                                              url: st.imageUrl,
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  st.caption.isNotEmpty ? st.caption : 'Story',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.primaryText,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: (st.isArchived ? CupertinoColors.systemGrey : const Color(0xFF34C759))
                                                            .withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        st.isArchived ? tr('ផុតកំណត់ 24h', 'Archived (>24h)') : tr('កំពុងបង្ហាញ 24h', 'Active (24h)'),
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: st.isArchived ? AppTheme.secondaryText : const Color(0xFF34C759),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(st.timeAgo, style: TextStyle(fontSize: 11, color: AppTheme.tertiaryText)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          CupertinoButton(
                                            padding: const EdgeInsets.all(6),
                                            onPressed: () async {
                                              final ok = await _api.deleteStory(st.id);
                                              if (ok) {
                                                setArchState(() => items.removeAt(idx));
                                              }
                                            },
                                            child: Icon(CupertinoIcons.trash, size: 18, color: AppTheme.accentCrimson),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openCreateMenuSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('បង្កើតមាតិកាថ្មី (Create Content)', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.square_pencil, color: Color(0xFF007AFF)),
                SizedBox(width: 8),
                Text('បង្កើតការបង្ហោះថ្មី (New Post)'),
              ],
            ),
            onPressed: () {
              Navigator.pop(ctx);
              CreatePostSheet.show(
                context,
                spaces: [],
                onPostCreated: (_) => _loadTabContent(),
              );
            },
          ),
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.film, color: Color(0xFFFF2D55)),
                SizedBox(width: 8),
                Text('បង្កើតវីដេអូខ្លី Reel (Create Reel)'),
              ],
            ),
            onPressed: () {
              Navigator.pop(ctx);
              CreateReelSheet.show(
                context,
                onReelCreated: _loadTabContent,
              );
            },
          ),
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera, color: Color(0xFF34C759)),
                SizedBox(width: 8),
                Text('បង្កើតរឿង Story (Add Story)'),
              ],
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _pickAndUploadAvatar();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('បោះបង់ (Cancel)'),
        ),
      ),
    );
  }

  void _openCreatorDashboardSheet() {
    final totalReactions = _myPosts.fold<int>(0, (sum, p) => sum + p.likeCount);
    final totalComments = _myPosts.fold<int>(0, (sum, p) => sum + p.commentCount);
    final reelsCount = _myPosts.where((p) => p.isReel || (p.videoUrl != null && p.videoUrl!.isNotEmpty)).length;
    final photosCount = _myPosts
        .where((p) => (p.imageUrl != null && p.imageUrl!.isNotEmpty) && !p.isReel && (p.videoUrl == null || p.videoUrl!.isEmpty))
        .length;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => LiquidGlassSheet(
        initialHeightFraction: 0.78,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'ផ្ទាំងគ្រប់គ្រងអ្នកបង្កើត (Professional Dashboard)',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.primaryText),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('$_followerCount', 'អ្នកតាមដាន'),
                    _buildStatCol('$_followingCount', 'កំពុងតាមដាន'),
                    _buildStatCol('${totalReactions + totalComments}', 'អន្តរកម្មពិត'),
                    _buildStatCol('\$${_bakongSalesTotalUsd.toStringAsFixed(2)}', 'ចំណូល Bakong'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'ឧបករណ៍គ្រប់គ្រង (Creator Tools):',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primaryText),
              ),
              const SizedBox(height: 10),
              CupertinoListTile(
                leading: const Icon(CupertinoIcons.chart_bar_alt_fill, color: Color(0xFF007AFF)),
                title: const Text('ស្ថិតិ & ទស្សនិកជន (Real Insights)'),
                subtitle: Text('${_myPosts.length} ប្រកាស • $reelsCount Reels • $photosCount រូបថត'),
                trailing: const Icon(CupertinoIcons.chevron_forward, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  showCupertinoDialog(
                    context: context,
                    builder: (dCtx) => CupertinoAlertDialog(
                      title: const Text('ស្ថិតិពិតរបស់គណនីអ្នក'),
                      content: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          '• ការបង្ហោះសរុប៖ ${_myPosts.length}\n'
                          '• វីដេអូ Reels៖ $reelsCount\n'
                          '• រូបថត៖ $photosCount\n'
                          '• ចំនួន Reactions សរុប៖ $totalReactions\n'
                          '• ចំនួន Comments សរុប៖ $totalComments\n'
                          '• មិត្តភក្តិពិត៖ ${_realFriends.length}\n'
                          '• ការលក់ Bakong បានទូទាត់៖ $_paidSalesCount (\$${_bakongSalesTotalUsd.toStringAsFixed(2)})',
                          textAlign: TextAlign.left,
                        ),
                      ),
                      actions: [
                        CupertinoDialogAction(
                          isDefaultAction: true,
                          child: const Text('យល់ព្រម'),
                          onPressed: () => Navigator.pop(dCtx),
                        ),
                      ],
                    ),
                  );
                },
              ),
              CupertinoListTile(
                leading: const Icon(CupertinoIcons.bag_fill, color: Color(0xFF34C759)),
                title: const Text('ការទូទាត់ Bakong KHQR (Payouts)'),
                subtitle: Text(
                  (_api.currentUser?.bakongAccountId?.isNotEmpty == true)
                      ? 'Bakong ID: ${_api.currentUser!.bakongAccountId}'
                      : 'មិនទាន់បានភ្ជាប់ Bakong ID ទេ',
                ),
                trailing: const Icon(CupertinoIcons.chevron_forward, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  _openStoreSettingsSheet();
                },
              ),
              CupertinoListTile(
                leading: const Icon(CupertinoIcons.rosette, color: Color(0xFFFF9500)),
                title: const Text('សញ្ញាផ្ទៀងផ្ទាត់ផ្លូវការ (Blue Checkmark VIP)'),
                trailing: const Icon(CupertinoIcons.chevron_forward, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  _openVipModal();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(IconData icon, String label, VoidCallback onTap) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryText),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCol(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF007AFF))),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.secondaryText)),
      ],
    );
  }

  void _openSettingsDrawerSheet() {
    final user = _api.currentUser;
    final isAdmin = user?.isAdmin ?? false;
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => LiquidGlassSheet(
          initialHeightFraction: 0.85,
          child: ListView(
            children: [
              Center(
                child: Text(
                  tr('ការកំណត់គណនី (Account Settings)', 'Account & Store Settings'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.primaryText),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border, width: 0.8),
                ),
                child: Column(
                  children: [
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.person_crop_circle_fill, color: Color(0xFF007AFF), size: 20),
                      title: Text(tr('កែសម្រួលព័ត៌មាន Profile', 'Edit Profile Info')),
                      subtitle: Text(user?.name ?? 'Name, Bio, Phone, Location'),
                      trailing: const Icon(CupertinoIcons.chevron_right, size: 17),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openEditProfileSheet();
                      },
                    ),
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.bag_fill, color: Color(0xFFE1251B), size: 20),
                      title: Text(tr('តុបតែងហាង & Bakong Payway', 'Decorate Store & Bakong')),
                      subtitle: Text(
                        (user?.storeName != null && user!.storeName!.isNotEmpty)
                            ? user.storeName!
                            : tr('កំណត់ហាងអនឡាញរបស់អ្នក', 'Customize your shop & KHQR'),
                      ),
                      trailing: const Icon(CupertinoIcons.chevron_right, size: 17),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openStoreSettingsSheet();
                      },
                    ),
                    Container(height: 0.5, color: AppTheme.divider),
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.device_phone_portrait, color: Color(0xFF007AFF), size: 20),
                      title: Text(tr('ដំឡើង Spaces លើទូរស័ព្ទ (PWA)', 'Add to Home Screen (PWA)')),
                      subtitle: Text(tr('ដំណើរការដូច App ពេញលេញលើទូរស័ព្ទ', 'Install on phone Home Screen')),
                      trailing: const Icon(CupertinoIcons.chevron_right, size: 17),
                      onTap: () {
                        Navigator.pop(ctx);
                        PwaInstallSheet.show(context);
                      },
                    ),
                    Container(height: 0.5, color: AppTheme.divider),
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.clock_fill, color: Color(0xFF0A84FF), size: 20),
                      title: Text(tr('ប្រវត្តិ Story (Story Archive 24h)', 'Story History Archive')),
                      subtitle: Text(tr('មើល Story ចាស់ៗដែលផុតកំណត់ 24 ម៉ោង', 'View active & 24h expired stories')),
                      trailing: const Icon(CupertinoIcons.chevron_right, size: 17),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openStoryArchiveSheet();
                      },
                    ),
                    Container(height: 0.5, color: AppTheme.divider),
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.moon_stars_fill, color: Color(0xFF5856D6), size: 20),
                      title: Text(tr('មុខងាររាត្រី (OLED Night Mode)', 'OLED Night Mode')),
                      trailing: ValueListenableBuilder<bool>(
                        valueListenable: _api.isDarkModeNotifier,
                        builder: (context, isDark, _) => CupertinoSwitch(
                          value: isDark,
                          activeColor: const Color(0xFF5856D6),
                          onChanged: (val) => _api.setThemeMode(val),
                        ),
                      ),
                    ),
                    Container(height: 0.5, color: AppTheme.divider),
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.leaf_arrow_circlepath, color: Color(0xFF34C759), size: 20),
                      title: Text(tr('Focus Mode (Calm Digest)', 'Focus Mode (Calm Digest)')),
                      trailing: CupertinoSwitch(
                        value: focusMode,
                        activeColor: const Color(0xFF34C759),
                        onChanged: (val) {
                          _updateFocusMode(val);
                          setSheetState(() {});
                        },
                      ),
                    ),
                    Container(height: 0.5, color: AppTheme.divider),
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.heart_slash, color: Color(0xFFFF2D55), size: 20),
                      title: Text(tr('លាក់ចំនួន Like (Hide Metrics)', 'Hide Like Counts')),
                      trailing: CupertinoSwitch(
                        value: hideMetrics,
                        activeColor: const Color(0xFF007AFF),
                        onChanged: (val) {
                          _updateHideMetrics(val);
                          setSheetState(() {});
                        },
                      ),
                    ),
                    Container(height: 0.5, color: AppTheme.divider),
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.bell_fill, color: Color(0xFFFF9500), size: 20),
                      title: Text(tr('ការជូនដំណឹងលើ Browser (Web Push)', 'Browser Notifications')),
                      subtitle: Text(
                        RealtimeService().browserPermissionStatus == 'granted'
                            ? tr('បានបើកដំណើរការ', 'Enabled')
                            : tr('ចុចដើម្បីបើកការជូនដំណឹងភ្លាមៗ', 'Tap to enable instant alerts'),
                      ),
                      trailing: const Icon(CupertinoIcons.chevron_right, size: 17),
                      onTap: () async {
                        final res = await RealtimeService().requestBrowserNotificationPermission();
                        setSheetState(() {});
                        if (ctx.mounted && res == 'granted') {
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                    Container(height: 0.5, color: AppTheme.divider),
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.person_crop_circle_badge_xmark, color: Color(0xFFFF3B30), size: 20),
                      title: Text(tr('គណនីដែលបាន Block (Blocked Users)', 'Blocked Users')),
                      trailing: const Icon(CupertinoIcons.chevron_right, size: 17),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openBlockedUsersSheet();
                      },
                    ),
                    Container(height: 0.5, color: AppTheme.divider),
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.lock_shield, color: Color(0xFF007AFF), size: 20),
                      title: Text(tr('ប្តូរពាក្យសម្ងាត់ (Change Password)', 'Change Password')),
                      trailing: const Icon(CupertinoIcons.chevron_right, size: 17),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openChangePasswordDialog();
                      },
                    ),
                    Container(height: 0.5, color: AppTheme.divider),
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.shield_lefthalf_fill, color: Color(0xFF34C759), size: 20),
                      title: Text(tr('ការផ្ទៀងផ្ទាត់ 2FA', 'Two-Factor Auth (2FA)')),
                      trailing: CupertinoSwitch(
                        value: _api.currentUser?.twoFactorEnabled ?? false,
                        activeColor: const Color(0xFF34C759),
                        onChanged: (_) async {
                          await _api.toggleTwoFactor();
                          setSheetState(() {});
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                    Container(height: 0.5, color: AppTheme.divider),
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.arrow_right_square, color: Color(0xFFFF3B30), size: 20),
                      title: Text(
                        tr('ចាកចេញពីគណនី (Log Out)', 'Log Out'),
                        style: const TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _confirmLogout();
                      },
                    ),
                  ],
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    'ADMIN SYSTEM INFRASTRUCTURE (ADMIN ONLY)',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFFF9500)),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border, width: 0.8),
                  ),
                  child: CupertinoListTile(
                    leading: const Icon(CupertinoIcons.flame_fill, color: Color(0xFFFF9500), size: 20),
                    title: const Text('Firebase Cloud Messaging (FCM)'),
                    subtitle: Text(tr('បានភ្ជាប់ជោគជ័យ (Admin Access)', 'Status: Connected / Active')),
                    trailing: const Text(
                      'ONLINE',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF34C759)),
                    ),
                  ),
                ),
              ],
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
            final personalName = rawName.isNotEmpty ? rawName : (isAdmin ? 'CHAN SOCHEAT' : 'អ្នកប្រើប្រាស់');
            final hasStore = user?.storeName != null && user!.storeName!.trim().isNotEmpty;
            final storeName = hasStore ? user.storeName!.trim() : 'ទំព័រអាជីវកម្ម (Business Page)';
            final userName = _isPageMode ? storeName : personalName;

            final userAvatar = (user?.avatar != null && user!.avatar.isNotEmpty)
                ? user.avatar
                : (isAdmin
                    ? '/uploads/admin_avatar.jpg'
                    : '/default_avatar.svg');
            final userBanner = (_isPageMode && user?.storeBannerUrl != null && user!.storeBannerUrl!.trim().isNotEmpty)
                ? user.storeBannerUrl!.trim()
                : (user?.bannerUrl?.trim() ?? '');

            return CupertinoPageScaffold(
      backgroundColor: AppTheme.scaffoldBg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppTheme.navBarBg,
        middle: GestureDetector(
          onTap: _showAccountOrPageSwitcher,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isPageMode
                  ? const Color(0xFF007AFF).withOpacity(0.15)
                  : CupertinoColors.systemGrey.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPageMode ? CupertinoIcons.flag_fill : CupertinoIcons.person_crop_circle_fill,
                  size: 14,
                  color: _isPageMode ? const Color(0xFF007AFF) : AppTheme.primaryText,
                ),
                const SizedBox(width: 5),
                Text(
                  _isPageMode ? storeName : tr('គណនីផ្ទាល់ខ្លួន', 'Profile'),
                  style: TextStyle(
                    color: _isPageMode ? const Color(0xFF007AFF) : AppTheme.primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 11,
                  color: _isPageMode ? const Color(0xFF007AFF) : AppTheme.secondaryText,
                ),
              ],
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiquidGlassPressable(
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
            const SizedBox(width: 6),
            LiquidGlassPressable(
              onTap: _openSettingsDrawerSheet,
              child: LiquidGlassContainer(
                borderRadius: 14,
                blurSigma: 14,
                padding: const EdgeInsets.all(6),
                child: Icon(CupertinoIcons.gear_solid, size: 16, color: AppTheme.primaryText),
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                ResponsiveLayout.horizontalPadding(context),
                12,
                ResponsiveLayout.horizontalPadding(context),
                ResponsiveLayout.bottomDockClearance(context) + 60,
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
                      if (userBanner.isNotEmpty)
                        MediaImageView(
                          url: userBanner,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF0A2E5C), Color(0xFF1C3A70), Color(0xFF1E293B)],
                            ),
                          ),
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

                  // Avatar & User Details (Facebook Profile Layout)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -45),
                          child: Column(
                            children: [
                              // Mood Speech Bubble
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.border, width: 0.8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'អារម្មណ៍បច្ចុប្បន្ន...',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.secondaryText,
                                  ),
                                ),
                              ),

                              // Circular Avatar with Camera Badge
                              GestureDetector(
                                onTap: _pickAndUploadAvatar,
                                child: Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3.5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cardBg,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.18),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(50),
                                        child: MediaImageView(
                                          url: userAvatar,
                                          width: 96,
                                          height: 96,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 2,
                                      right: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppTheme.cardBg, width: 1.5),
                                        ),
                                        child: Icon(
                                          CupertinoIcons.camera_fill,
                                          size: 15,
                                          color: isDark ? CupertinoColors.white : const Color(0xFF050505),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Name & Verified Badge
                        Transform.translate(
                          offset: const Offset(0, -32),
                          child: Builder(
                            builder: (context) {
                              final isVerifiedUser = (user?.isVerified == true) || (user?.isVip == true) || (user?.isAdmin == true);
                              final displayBio = _isPageMode
                                  ? ((user?.storeTagline != null && user!.storeTagline!.trim().isNotEmpty)
                                      ? user.storeTagline!.trim()
                                      : ((user?.storeDescription != null && user!.storeDescription!.trim().isNotEmpty)
                                          ? user.storeDescription!.trim()
                                          : 'ទំព័រអាជីវកម្មផ្លូវការ (Official Business Page)'))
                                  : (user?.bio != null && user!.bio!.trim().isNotEmpty ? user.bio!.trim() : null);

                              return Column(
                                children: [
                                  Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    userName,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primaryText,
                                    ),
                                  ),
                                  if (isVerifiedUser) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: _openVipModal,
                                      child: const Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFF007AFF), size: 20),
                                    ),
                                  ] else ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: _openVipModal,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF007AFF).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.3)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(CupertinoIcons.shield_lefthalf_fill, size: 11, color: Color(0xFF007AFF)),
                                            SizedBox(width: 3),
                                            Text(
                                              'Get Verified',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF007AFF)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              if (displayBio != null) ...[
                                Text(
                                  displayBio,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.secondaryText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  '@${user?.username ?? ""} • ${user?.location ?? "Cambodia"}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.secondaryText,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 5),
                              Text(
                                'អ្នកតាមដាន $_followerCount នាក់  •  កំពុងតាមដាន $_followingCount នាក់',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryText.withOpacity(0.85),
                                ),
                              ),
                              if (user?.storePhone != null && user!.storePhone!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'ទំនាក់ទំនង: ${user.storePhone!.trim()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF007AFF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else if (user?.email != null && user!.email!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Email: ${user.email!.trim()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF007AFF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (_realFriends.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: (_realFriends.take(3).length * 16.0 + 8.0).clamp(24.0, 60.0),
                                      height: 24,
                                      child: Stack(
                                        children: [
                                          for (int i = 0; i < _realFriends.take(3).length; i++)
                                            Positioned(
                                              left: i * 14.0,
                                              child: Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: AppTheme.cardBg, width: 1.5),
                                                ),
                                                child: ClipOval(
                                                  child: MediaImageView(url: _realFriends[i].avatar.isNotEmpty ? _realFriends[i].avatar : '/default_avatar.svg'),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'មិត្តភក្តិ ${_realFriends.length} នាក់',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.secondaryText,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 14),

                              // Main Facebook Action Buttons: [📊 ផ្ទាំងគ្រប់គ្រង] & [+ បង្កើត] & [⚙️ ការកំណត់]
                              Row(
                                children: [
                                  Expanded(
                                    child: CupertinoButton(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      color: const Color(0xFF007AFF),
                                      borderRadius: BorderRadius.circular(12),
                                      onPressed: _openCreatorDashboardSheet,
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(CupertinoIcons.chart_bar_alt_fill, size: 16, color: CupertinoColors.white),
                                          SizedBox(width: 6),
                                          Text(
                                            'ផ្ទាំងគ្រប់គ្រង',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: CupertinoColors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: CupertinoButton(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
                                      borderRadius: BorderRadius.circular(12),
                                      onPressed: _openCreateMenuSheet,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            CupertinoIcons.plus,
                                            size: 16,
                                            color: isDark ? CupertinoColors.white : const Color(0xFF050505),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'បង្កើត',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? CupertinoColors.white : const Color(0xFF050505),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
                                    borderRadius: BorderRadius.circular(12),
                                    onPressed: _openSettingsDrawerSheet,
                                    child: Icon(
                                      CupertinoIcons.gear_solid,
                                      size: 18,
                                      color: isDark ? CupertinoColors.white : const Color(0xFF050505),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Facebook Profile Segment Tabs: [ទាំងអស់] [Reels] [រូបថត] [ព្រឹត្តិការណ៍]
            LiquidGlassSegmentControl<int>(
              groupValue: _selectedTab,
              items: [
                LiquidGlassSegmentItem(
                  value: 1,
                  label: 'ទាំងអស់',
                  icon: CupertinoIcons.square_grid_2x2,
                ),
                LiquidGlassSegmentItem(
                  value: 2,
                  label: 'Reels',
                  icon: CupertinoIcons.film,
                ),
                LiquidGlassSegmentItem(
                  value: 3,
                  label: 'រូបថត',
                  icon: CupertinoIcons.photo,
                ),
                LiquidGlassSegmentItem(
                  value: 4,
                  label: 'ព្រឹត្តិការណ៍',
                  icon: CupertinoIcons.calendar,
                ),
              ],
              onValueChanged: (val) {
                setState(() => _selectedTab = val);
                _loadTabContent();
              },
            ),
            const SizedBox(height: 12),

            // Quick Action Chips: [🔖 បានរក្សាទុក] [👍 បានចូលចិត្ត] [🎬 Reels របស់ខ្ញុំ] [🛡️ ពិនិត្យគណនី]
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildQuickActionChip(CupertinoIcons.bookmark, 'បានរក្សាទុក', () {
                    setState(() => _selectedTab = 5); // Saved tab
                    _loadTabContent();
                  }),
                  const SizedBox(width: 8),
                  _buildQuickActionChip(CupertinoIcons.hand_thumbsup, 'បានចូលចិត្ត', () {
                    setState(() => _selectedTab = 6); // Liked tab
                    _loadTabContent();
                  }),
                  const SizedBox(width: 8),
                  _buildQuickActionChip(CupertinoIcons.film, 'Reels របស់ខ្ញុំ', () {
                    setState(() => _selectedTab = 2); // Reels tab
                    _loadTabContent();
                  }),
                  const SizedBox(width: 8),
                  _buildQuickActionChip(CupertinoIcons.eye, 'ពិនិត្យគណនី', _openProfileHealthCheckSheet),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab 1: All Posts
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

            // Tab 2: Real User Reels
            if (_selectedTab == 2) ...[
              if (_isLoadingPosts)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CupertinoActivityIndicator(radius: 14),
                  ),
                )
              else ...[
                Builder(builder: (context) {
                  final myReels = _myPosts.where((p) => p.isReel || (p.videoUrl != null && p.videoUrl!.isNotEmpty)).toList();
                  if (myReels.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border, width: 0.8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                              child: Icon(
                                CupertinoIcons.film_fill,
                                size: 46,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'មិនទាន់មានរ៉េលទេ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryText,
                            ),
                          ),
                          const SizedBox(height: 18),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            color: const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(12),
                            onPressed: () {
                              CreateReelSheet.show(context, onReelCreated: _loadTabContent);
                            },
                            child: const Text(
                              'បង្កើតរ៉េល',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(10),
                            onPressed: () => CreateReelSheet.show(context, onReelCreated: _loadTabContent),
                            child: const Text(
                              '+ បង្កើតរ៉េលថ្មី',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CupertinoColors.white),
                            ),
                          ),
                        ),
                      ),
                      ...myReels.map(
                        (post) => PostCard(
                          post: post,
                          onCommentTap: () => _openComments(post),
                          onPostDeleted: _loadTabContent,
                          onPostUpdated: _loadTabContent,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ],

            // Tab 3: Real User Photos Grid
            if (_selectedTab == 3) ...[
              if (_isLoadingPosts)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CupertinoActivityIndicator(radius: 14),
                  ),
                )
              else ...[
                Builder(builder: (context) {
                  final myPhotos = _myPosts
                      .where((p) =>
                          (p.imageUrl != null && p.imageUrl!.isNotEmpty) &&
                          !p.isReel &&
                          (p.videoUrl == null || p.videoUrl!.isEmpty))
                      .toList();
                  if (myPhotos.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.border, width: 0.6),
                      ),
                      child: Column(
                        children: [
                          const Icon(CupertinoIcons.photo, size: 40, color: CupertinoColors.systemGrey3),
                          const SizedBox(height: 12),
                          Text(
                            'មិនទាន់មានរូបថតដែលបានបង្ហោះនៅឡើយទេ',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.secondaryText, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            color: const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(10),
                            onPressed: _openCreateMenuSheet,
                            child: const Text(
                              '+ បង្ហោះរូបថត',
                              style: TextStyle(color: CupertinoColors.white, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: myPhotos.length,
                    itemBuilder: (ctx, idx) {
                      final photoPost = myPhotos[idx];
                      return GestureDetector(
                        onTap: () => _openComments(photoPost),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: MediaImageView(
                            url: photoPost.imageUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  );
                }),
              ],
            ],

            // Tab 4: Events & Streams Created by User
            if (_selectedTab == 4) ...[
              if (_isLoadingPosts)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CupertinoActivityIndicator(radius: 14),
                  ),
                )
              else if (_myStreams.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border, width: 0.6),
                  ),
                  child: Column(
                    children: [
                      const Icon(CupertinoIcons.calendar, size: 40, color: CupertinoColors.systemGrey3),
                      const SizedBox(height: 12),
                      Text(
                        'មិនទាន់មានការផ្សាយផ្ទាល់ ឬព្រឹត្តិការណ៍ទេ',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.secondaryText, height: 1.4),
                      ),
                    ],
                  ),
                )
              else
                ..._myStreams.map(
                  (st) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border, width: 0.8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: st.isLive ? const Color(0xFFFF3B30).withOpacity(0.15) : const Color(0xFF007AFF).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            st.isLive ? CupertinoIcons.dot_radiowaves_left_right : CupertinoIcons.play_rectangle_fill,
                            color: st.isLive ? const Color(0xFFFF3B30) : const Color(0xFF007AFF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                st.title,
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.primaryText),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${st.isLive ? "🔴 កំពុងផ្សាយផ្ទាល់" : "វីដេអូ/ព្រឹត្តិការណ៍"} • អ្នកមើល ${st.viewerCount}',
                                style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            // Tab 5: Saved Posts
            if (_selectedTab == 5) ...[
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

            // Tab 6: Liked Posts
            if (_selectedTab == 6) ...[
              if (_isLoadingPosts)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CupertinoActivityIndicator(radius: 14),
                  ),
                )
              else if (_likedPosts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border, width: 0.6),
                  ),
                  child: Column(
                    children: [
                      const Icon(CupertinoIcons.hand_thumbsup, size: 40, color: CupertinoColors.systemGrey3),
                      const SizedBox(height: 12),
                      Text(
                        'មិនទាន់មានការបង្ហោះដែលអ្នកបានចូលចិត្តទេ',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.secondaryText, height: 1.4),
                      ),
                    ],
                  ),
                )
              else
                ..._likedPosts.map(
                  (post) => PostCard(
                    post: post,
                    onCommentTap: () => _openComments(post),
                    onPostDeleted: _loadTabContent,
                    onPostUpdated: _loadTabContent,
                  ),
                ),
            ],
            const SizedBox(height: 50),
          ],
        ),
      ),
    ),
  ),
);
          },
        );
      },
    );
  }

  void _openProfileHealthCheckSheet() {
    final user = _api.currentUser;
    final hasAvatar = user?.avatar != null && !user!.avatar.contains('default_avatar');
    final hasBanner = user?.bannerUrl != null && user!.bannerUrl!.isNotEmpty;
    final hasBio = user?.bio != null && user!.bio!.isNotEmpty;
    final hasBakong = user?.bakongAccountId != null && user!.bakongAccountId!.contains('@');
    final has2fa = user?.twoFactorEnabled == true;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('ពិនិត្យស្ថានភាពគណនី (Account Review)', style: TextStyle(fontWeight: FontWeight.w700)),
        message: const Text('ចុចលើចំណុចណាមួយដើម្បីកែសម្រួលឱ្យគណនីកាន់តែពេញលេញ និងសុវត្ថិភាព'),
        actions: [
          CupertinoActionSheetAction(
            child: Text('${hasAvatar ? "✅" : "⚠️"} រូបតំណាង (Profile Avatar)'),
            onPressed: () {
              Navigator.pop(ctx);
              _pickAndUploadAvatar();
            },
          ),
          CupertinoActionSheetAction(
            child: Text('${hasBanner ? "✅" : "⚠️"} រូបភាព Banner (Cover Photo)'),
            onPressed: () {
              Navigator.pop(ctx);
              _openChangeBannerSheet();
            },
          ),
          CupertinoActionSheetAction(
            child: Text('${hasBio ? "✅" : "⚠️"} ព័ត៌មាន Bio & ទីតាំង'),
            onPressed: () {
              Navigator.pop(ctx);
              _openEditProfileSheet();
            },
          ),
          CupertinoActionSheetAction(
            child: Text('${hasBakong ? "✅" : "⚠️"} Bakong KHQR ID (${hasBakong ? user.bakongAccountId : "មិនទាន់ភ្ជាប់"})'),
            onPressed: () {
              Navigator.pop(ctx);
              _openStoreSettingsSheet();
            },
          ),
          CupertinoActionSheetAction(
            child: Text('${has2fa ? "✅" : "⚠️"} សុវត្ថិភាព 2FA (${has2fa ? "បើក" : "បិទ"})'),
            onPressed: () {
              Navigator.pop(ctx);
              _openSettingsDrawerSheet();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('បិទ'),
        ),
      ),
    );
  }

  Future<void> _openBlockedUsersSheet() async {
    final blocked = await _api.fetchBlockedUsers();
    if (!mounted) return;
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => LiquidGlassSheet(
          initialHeightFraction: 0.6,
          child: Column(
            children: [
              Text(
                tr('គណនីដែលបាន Block (${blocked.length})', 'Blocked Accounts (${blocked.length})'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.primaryText),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: blocked.isEmpty
                    ? Center(
                        child: Text(
                          tr('មិនទាន់មានគណនីដែលបាន Block ទេ', 'No blocked users'),
                          style: TextStyle(color: AppTheme.secondaryText),
                        ),
                      )
                    : ListView.separated(
                        itemCount: blocked.length,
                        separatorBuilder: (_, __) => Container(height: 0.5, color: AppTheme.divider),
                        itemBuilder: (_, idx) {
                          final u = blocked[idx];
                          return CupertinoListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: MediaImageView(
                                url: u['avatar']?.toString() ?? '/default_avatar.svg',
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(u['name']?.toString() ?? 'User'),
                            subtitle: Text('@${u['username'] ?? ''}'),
                            trailing: CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              color: const Color(0xFF007AFF),
                              borderRadius: BorderRadius.circular(10),
                              onPressed: () async {
                                await _api.toggleBlockUser(u['id']?.toString() ?? '');
                                blocked.removeAt(idx);
                                setModalState(() {});
                                _loadTabContent();
                              },
                              child: Text(
                                tr('បើកវិញ', 'Unblock'),
                                style: const TextStyle(fontSize: 12, color: CupertinoColors.white),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
