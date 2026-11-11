import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';

class VipSubscriptionSheet extends StatefulWidget {
  final VoidCallback onSubscribed;

  const VipSubscriptionSheet({super.key, required this.onSubscribed});

  @override
  State<VipSubscriptionSheet> createState() => _VipSubscriptionSheetState();
}

class _VipSubscriptionSheetState extends State<VipSubscriptionSheet> {
  String _selectedTier = 'PRO_PLUS'; // 'PRO_PLUS' | 'ULTRA'
  int _selectedDuration = 1; // months: 1 or 2 for PRO_PLUS, 12 for ULTRA
  bool _isGeneratingQr = false;
  bool _isCheckingStatus = false;
  Map<String, dynamic>? _checkoutData;
  Timer? _pollTimer;
  bool _isPaid = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  double get _priceUsd {
    if (_selectedTier == 'PRO_PLUS') {
      return _selectedDuration == 1 ? 0.50 : 3.00;
    } else {
      return 15.00; // Ultra is annual
    }
  }

  int get _priceKhr => (_priceUsd * 4100).round();

  void _onTierSelected(String tier) {
    _pollTimer?.cancel();
    setState(() {
      _selectedTier = tier;
      if (tier == 'ULTRA') {
        _selectedDuration = 12;
      } else {
        _selectedDuration = 1;
      }
      _checkoutData = null;
      _errorMessage = null;
    });
  }

  void _startKhqrCheckout() async {
    _pollTimer?.cancel();
    setState(() {
      _isGeneratingQr = true;
      _errorMessage = null;
    });

    final res = await ApiService().checkoutVip(
      tier: _selectedTier,
      durationMonths: _selectedDuration,
      amount: _priceUsd,
    );

    if (mounted) {
      if (res != null && res['md5'] != null) {
        setState(() {
          _checkoutData = res;
          _isGeneratingQr = false;
        });
        _startPolling(res['md5'] as String);
      } else {
        setState(() {
          _isGeneratingQr = false;
          _errorMessage = tr('មិនអាចបង្កើតកូដ KHQR បានទេ សូមព្យាយាមម្តងទៀត', 'Failed to generate Bakong KHQR. Please retry.');
        });
      }
    }
  }

  void _startPolling(String md5) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final res = await ApiService().checkVipStatus(md5);
      if (mounted && res != null && res['paid'] == true) {
        timer.cancel();
        setState(() {
          _isPaid = true;
        });
        widget.onSubscribed();
      }
    });
  }

  void _manualCheckStatus() async {
    final md5 = _checkoutData?['md5'] as String?;
    if (md5 == null) return;
    setState(() => _isCheckingStatus = true);
    final res = await ApiService().checkVipStatus(md5);
    if (mounted) {
      setState(() => _isCheckingStatus = false);
      if (res != null && res['paid'] == true) {
        _pollTimer?.cancel();
        setState(() => _isPaid = true);
        widget.onSubscribed();
      } else {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(tr('ស្ថានភាពទូទាត់', 'Payment Status')),
            content: Text(tr(
              'មិនទាន់ឃើញការផ្ទេរប្រាក់លើ NBC Ledger នៅឡើយទេ សូមបញ្ចប់ការស្កេនទូទាត់ក្នុង App ធនាគាររបស់អ្នក។',
              'Transaction not yet confirmed on NBC Ledger. Please finish scanning in your mobile banking app.',
            )),
            actions: [
              CupertinoDialogAction(
                child: Text(tr('យល់ព្រម', 'OK')),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildQrImageWidget(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return Container(
        width: 170,
        height: 170,
        color: CupertinoColors.systemGrey6,
        child: const Center(
          child: Icon(CupertinoIcons.qrcode, size: 80, color: CupertinoColors.systemGrey),
        ),
      );
    }

    try {
      String cleanBase64 = base64String;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',')[1];
      }
      final bytes = base64Decode(cleanBase64);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes,
          width: 180,
          height: 180,
          fit: BoxFit.contain,
        ),
      );
    } catch (e) {
      return Container(
        width: 170,
        height: 170,
        color: CupertinoColors.systemGrey6,
        child: const Center(
          child: Icon(CupertinoIcons.exclamationmark_triangle, size: 40, color: CupertinoColors.systemRed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: 12),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.checkmark_seal_fill, color: CupertinoColors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('ដោះសោសញ្ញា Blue Checkmark', 'Unlock Verified Blue Checkmark'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryText,
                        ),
                      ),
                      Text(
                        tr('ទទួលបានសញ្ញាផ្ទៀងផ្ទាត់ផ្លូវការ និងមុខងារពិសេស VIP', 'Get verified badge & VIP priority features'),
                        style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                      ),
                    ],
                  ),
                ],
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: const Icon(CupertinoIcons.clear_circled_solid, color: CupertinoColors.systemGrey2, size: 26),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Content
          Expanded(
            child: _isPaid ? _buildPaidSuccessView() : _buildSubscriptionContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildPaidSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.checkmark_seal_fill,
                size: 80,
                color: Color(0xFF007AFF),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tr('ការទូទាត់ជោគជ័យ!', 'Payment Confirmed!'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryText,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              tr(
                'គណនីរបស់អ្នកត្រូវបានផ្ទៀងផ្ទាត់ និងដោះសោសញ្ញា Blue Checkmark ផ្លូវការរួចរាល់ហើយ!',
                'Your account has been verified and awarded the official Blue Checkmark badge on NBC Ledger!',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(14),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  tr('រួចរាល់ (Done)', 'Done'),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: CupertinoColors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tier Selector Cards
          Row(
            children: [
              Expanded(
                child: _buildTierCard(
                  tier: 'PRO_PLUS',
                  title: 'Pro Plus',
                  icon: CupertinoIcons.sparkles,
                  color: const Color(0xFF007AFF),
                  badgeText: tr('ពេញនិយមបំផុត', 'POPULAR'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTierCard(
                  tier: 'ULTRA',
                  title: 'Ultra VIP',
                  icon: CupertinoIcons.star_fill,
                  color: const Color(0xFFFF9500),
                  badgeText: tr('ប្រណិតបំផុត', 'PREMIUM'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Duration Selector (for Pro Plus)
          if (_selectedTier == 'PRO_PLUS') ...[
            Text(
              tr('ជ្រើសរើសរយៈពេលជាវ', 'Select Duration'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDurationOption(
                    duration: 1,
                    label: tr('1 ខែ (\$0.50)', '1 Month (\$0.50)'),
                    sublabel: tr('សាកល្បង', 'Starter Promo'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDurationOption(
                    duration: 2,
                    label: tr('2 ខែ (\$3.00)', '2 Months (\$3.00)'),
                    sublabel: tr('ចំណេញ', 'Standard'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Benefits List
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('អត្ថប្រយោជន៍ដែលទទួលបាន:', 'Included Benefits:'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 10),
                _buildBenefitRow(CupertinoIcons.checkmark_seal_fill, const Color(0xFF007AFF), tr('សញ្ញាផ្ទៀងផ្ទាត់ Blue Checkmark លើ Profile & Feed', 'Verified Blue Checkmark on Profile & Feed')),
                _buildBenefitRow(CupertinoIcons.arrow_up_circle_fill, const Color(0xFF34C759), tr('រុញការផុស និងទំនិញឡើងលើគេក្នុង Marketplace', 'Priority boost on Posts and Store products')),
                _buildBenefitRow(CupertinoIcons.videocam_fill, const Color(0xFFFF2D55), tr('បង្ហោះវីដេអូ Reels និងរូបភាពកម្រិត HD ច្បាស់ខ្លាំង', 'HD Reels and unlimited photo/video upload')),
                _buildBenefitRow(CupertinoIcons.shield_fill, const Color(0xFF5856D6), tr('ការការពារគណនីកម្រិតខ្ពស់ និងជំនួយការ Support', 'Advanced account protection and priority support')),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // KHQR Payment Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE1251B).withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE1251B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(CupertinoIcons.qrcode_viewfinder, color: Color(0xFFE1251B), size: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Bakong KHQR Payment',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE1251B),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '\$$_priceUsd (~ $_priceKhr ៛)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isGeneratingQr) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        CupertinoActivityIndicator(radius: 14),
                        SizedBox(height: 10),
                        Text('កំពុងបង្កើតកូដ Bakong KHQR...', style: TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel)),
                      ],
                    ),
                  ),
                ] else if (_checkoutData != null) ...[
                  // Real KHQR Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE1251B),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'KHQR',
                                style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w900, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'BAKONG',
                              style: TextStyle(color: Color(0xFFE1251B), fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildQrImageWidget(_checkoutData?['qrImage'] as String?),
                        const SizedBox(height: 8),
                        Text(
                          'CHAN SOCHEAT',
                          style: const TextStyle(color: CupertinoColors.black, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        Text(
                          'chansocheat_vin@bkrt',
                          style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoActivityIndicator(radius: 8),
                      SizedBox(width: 8),
                      Text(
                        'កំពុងរង់ចាំការទូទាត់លើ NBC Ledger...',
                        style: TextStyle(fontSize: 12, color: Color(0xFF007AFF), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          color: const Color(0xFF34C759),
                          borderRadius: BorderRadius.circular(12),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          onPressed: _isCheckingStatus ? null : _manualCheckStatus,
                          child: _isCheckingStatus
                              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                              : Text(
                                  tr('ពិនិត្យការបង់ប្រាក់', 'Check Status'),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: CupertinoColors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 12),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: const Color(0xFFE1251B),
                      borderRadius: BorderRadius.circular(14),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: _startKhqrCheckout,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.qrcode, color: CupertinoColors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            tr('បង្កើតកូដ KHQR ស្កេនបង់ប្រាក់', 'Generate KHQR to Pay'),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: CupertinoColors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTierCard({
    required String tier,
    required String title,
    required IconData icon,
    required Color color,
    required String badgeText,
  }) {
    final isSelected = _selectedTier == tier;
    return GestureDetector(
      onTap: () => _onTierSelected(tier),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppTheme.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tier == 'PRO_PLUS' ? '\$0.50 /mo' : '\$15.00 /yr',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationOption({
    required int duration,
    required String label,
    required String sublabel,
  }) {
    final isSelected = _selectedDuration == duration;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDuration = duration;
          _checkoutData = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF007AFF).withOpacity(0.1) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF007AFF) : AppTheme.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? const Color(0xFF007AFF) : AppTheme.primaryText,
              ),
            ),
            Text(
              sublabel,
              style: TextStyle(fontSize: 11, color: AppTheme.secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: AppTheme.primaryText, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
