import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../utils/google_auth_helper.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/pwa_install_banner.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final ApiService _api = ApiService();

  // Mode: 0 = Login (ចូលគណនី), 1 = Register (បង្កើតគណនីថ្មី)
  int _selectedSegment = 0;

  // Controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleSigningIn = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }



  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'សូមបញ្ចូលលេខទូរស័ព្ទ និងពាក្យសម្ងាត់ឱ្យបានត្រឹមត្រូវ';
      });
      return;
    }

    if (_selectedSegment == 0) {
      // Login
      final res = await _api.login(phone, password);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] != true) {
        setState(() {
          _errorMessage = res['message'] ?? 'លេខទូរស័ព្ទ ឬពាក្យសម្ងាត់មិនត្រឹមត្រូវ';
        });
      }
    } else {
      // Register
      final name = _nameController.text.trim();
      final username = _usernameController.text.trim().replaceAll(RegExp(r'^@+'), '');
      final email = _emailController.text.trim();

      if (name.isEmpty || username.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'សូមបញ្ចូលឈ្មោះពេញ និងឈ្មោះគណនី (username)';
        });
        return;
      }

      final res = await _api.register(
        phone: phone,
        name: name,
        username: username,
        password: password,
        email: email.isNotEmpty ? email : null,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] != true) {
        setState(() {
          _errorMessage = res['message'] ?? 'ការចុះឈ្មោះមិនជោគជ័យ';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.scaffoldBg,
      child: LiquidGlassAmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveLayout.horizontalPadding(context) + 6,
                vertical: 20.0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Brand Logo & Typography
                    _buildLogoHeader(isDark),
                    const SizedBox(height: 20),

                    // PWA Install to Home Screen Prompt (Web & Mobile Browsers)
                    const PwaInstallBanner(),

                    // Liquid Glass Segmented Control (ចូលគណនី / បង្កើតគណនី)
                    LiquidGlassSegmentControl<int>(
                      groupValue: _selectedSegment,
                      items: const [
                        LiquidGlassSegmentItem(
                          value: 0,
                          label: 'ចូលគណនី',
                          icon: CupertinoIcons.lock_open_fill,
                        ),
                        LiquidGlassSegmentItem(
                          value: 1,
                          label: 'បង្កើតគណនីថ្មី',
                          icon: CupertinoIcons.person_badge_plus_fill,
                        ),
                      ],
                      onValueChanged: (val) {
                        setState(() {
                          _selectedSegment = val;
                          _errorMessage = null;
                        });
                      },
                    ),
                    const SizedBox(height: 22),

                // Error Message banner if any
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: CupertinoColors.destructiveRed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CupertinoColors.destructiveRed.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_circle_fill,
                            color: CupertinoColors.destructiveRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.destructiveRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_selectedSegment == 1 &&
                            (_errorMessage!.contains('ចុះឈ្មោះរួច') ||
                             _errorMessage!.contains('ទូរស័ព្ទ') ||
                             _errorMessage!.contains('already'))) ...[
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            minSize: 0,
                            color: const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(8),
                            onPressed: () {
                              setState(() {
                                _selectedSegment = 0; // Switch to Login
                                _errorMessage = null;
                              });
                            },
                            child: const Text(
                              'ចូលគណនី',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // Form Fields Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_selectedSegment == 1) ...[
                        _buildInputField(
                          controller: _nameController,
                          placeholder: 'ឈ្មោះពេញ (Full Name)',
                          icon: CupertinoIcons.person,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildInputField(
                          controller: _usernameController,
                          placeholder: 'ឈ្មោះគណនី (Username ឧ. chanthy_dev)',
                          icon: CupertinoIcons.at,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildInputField(
                          controller: _emailController,
                          placeholder: 'អ៊ីមែល (Email - ស្រេចចិត្ត)',
                          icon: CupertinoIcons.mail,
                          keyboardType: TextInputType.emailAddress,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildInputField(
                        controller: _phoneController,
                        placeholder: 'លេខទូរស័ព្ទ (Phone ឧ. 012 345 678)',
                        icon: CupertinoIcons.phone,
                        keyboardType: TextInputType.phone,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildInputField(
                        controller: _passwordController,
                        placeholder: 'ពាក្យសម្ងាត់ (Password)',
                        icon: CupertinoIcons.lock,
                        obscureText: _obscurePassword,
                        isDark: isDark,
                        suffix: CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minSize: 0,
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          child: Icon(
                            _obscurePassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                            size: 18,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit Button
                      CupertinoButton(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(12),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                            : Text(
                                _selectedSegment == 0 ? 'ចូលគណនី' : 'បង្កើតគណនីភ្លាមៗ',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.white,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Divider OR
                Row(
                  children: [
                    Expanded(child: Container(height: 0.5, color: CupertinoColors.systemGrey4)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'ឬ',
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.systemGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: Container(height: 0.5, color: CupertinoColors.systemGrey4)),
                  ],
                ),
                const SizedBox(height: 16),

                // Continue with Google Button
                _buildGoogleButton(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildLogoHeader(bool isDark) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF007AFF).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              CupertinoIcons.circle_grid_hex_fill,
              size: 40,
              color: CupertinoColors.white,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Spaces Cambodia',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: isDark ? CupertinoColors.white : CupertinoColors.black,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'បណ្ដាញសង្គមឯកជនភាព និងសុវត្ថិភាពខ្ពស់',
          style: TextStyle(
            fontSize: 13,
            color: CupertinoColors.systemGrey,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffix,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA),
          width: 1,
        ),
      ),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        placeholderStyle: const TextStyle(
          fontSize: 14,
          color: CupertinoColors.systemGrey2,
        ),
        obscureText: obscureText,
        keyboardType: keyboardType,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Icon(icon, size: 19, color: CupertinoColors.systemGrey),
        ),
        suffix: suffix,
        decoration: null,
        style: TextStyle(
          fontSize: 15,
          color: isDark ? CupertinoColors.white : CupertinoColors.black,
        ),
      ),
    );
  }

  void _openGoogleSignInDialog(bool isDark) {
    final emailCtrl = TextEditingController();
    bool isSubmitting = false;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
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
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: CupertinoColors.systemGrey4, width: 0.8),
                      ),
                      child: const Text(
                        'G',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF4285F4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Google / Gmail Sign-In',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? CupertinoColors.white : CupertinoColors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'បញ្ចូល Gmail របស់អ្នកដើម្បីចូលគណនីភ្លាមៗ។ ប្រព័ន្ធនឹងទាញយកឈ្មោះពីមុខ Gmail ធ្វើជាឈ្មោះ Default លើ Profile ដោយស្វ័យប្រវត្តិ។',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? CupertinoColors.systemGrey : CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: emailCtrl,
                  placeholder: 'ឧទាហរណ៍៖ socheat_ue@gmail.com',
                  keyboardType: TextInputType.emailAddress,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  style: TextStyle(color: isDark ? CupertinoColors.white : CupertinoColors.black),
                ),
                const SizedBox(height: 18),
                CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(12),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final email = emailCtrl.text.trim();
                          if (!email.contains('@')) return;
                          setDialogState(() => isSubmitting = true);
                          final res = await _api.loginWithGoogle(email: email);
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          if (res['success'] != true && mounted) {
                            setState(() {
                              _errorMessage = res['message'] ?? 'បរាជ័យក្នុងការចូលតាម Google';
                            });
                          }
                        },
                  child: isSubmitting
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : const Text('ចូលគណនីជាមួយ Gmail ឥឡូវនេះ', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleGoogleSignIn(bool isDark) async {
    setState(() => _isGoogleSigningIn = true);
    final success = await GoogleAuthHelper.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleSigningIn = false);
    if (!success) {
      _openGoogleSignInDialog(isDark);
    }
  }

  Widget _buildGoogleButton(bool isDark) {
    return CupertinoButton(
      color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      borderRadius: BorderRadius.circular(12),
      onPressed: _isGoogleSigningIn ? null : () => _handleGoogleSignIn(isDark),
      child: _isGoogleSigningIn
          ? const CupertinoActivityIndicator()
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: CupertinoColors.systemGrey4, width: 0.8),
                  ),
                  child: const Text(
                    'G',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Color(0xFF4285F4),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'បន្តជាមួយ Google (Continue with Google)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? CupertinoColors.white : CupertinoColors.black,
                  ),
                ),
              ],
            ),
    );
  }
}

