import 'package:flutter/cupertino.dart';
import '../services/theme_service.dart';
import '../utils/pwa_helper.dart';
import 'liquid_glass.dart';

class PwaInstallSheet extends StatelessWidget {
  const PwaInstallSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showCupertinoModalPopup<void>(
      context: context,
      barrierColor: CupertinoColors.black.withOpacity(0.55),
      builder: (ctx) => const PwaInstallSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final isIos = PwaHelper.isIosSafari();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161820) : CupertinoColors.systemBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withOpacity(0.35),
              blurRadius: 28,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag indicator
            Container(
              width: 38,
              height: 4.5,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF48484A) : const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // App Icon with luxury glowing border
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
                    color: const Color(0xFF007AFF).withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.device_phone_portrait,
                  color: CupertinoColors.white,
                  size: 38,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Title
            Text(
              'ដំឡើង Spaces Cambodia',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryText,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'បន្ថែមទៅអេក្រង់ដើម (Add to Home Screen) ដើម្បីដំណើរការលឿន ដូច App ទូរស័ព្ទពេញលេញ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.secondaryText,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),

            // Direct Native Install Button (Chrome / Edge / Samsung Internet)
            LiquidGlassButton(
              label: 'ចុចដំឡើង App ឥឡូវនេះ (Install Now)',
              icon: CupertinoIcons.arrow_down_circle_fill,
              expand: true,
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: () async {
                Navigator.of(context).pop();
                await PwaHelper.triggerInstallPrompt(
                  onNeedManualGuide: () {
                    if (context.mounted) {
                      PwaInstallSheet.show(context);
                    }
                  },
                );
              },
            ),

            const SizedBox(height: 20),

            // Step-by-Step Instructions Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E212D) : const Color(0xFFF2F4F8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C2F3E) : const Color(0xFFE2E5EC),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isIos ? CupertinoIcons.compass : CupertinoIcons.settings,
                        size: 16,
                        color: const Color(0xFF007AFF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isIos ? 'ការណែនាំសម្រាប់ iPhone (Safari)' : 'ការណែនាំសម្រាប់ទូរស័ព្ទ Android / Chrome',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isIos) ...[
                    _buildStepRow(
                      context,
                      '១',
                      'ចុចប៊ូតុងចែករំលែក (Share ⎋) នៅរបារខាងក្រោមនៃ Safari',
                      CupertinoIcons.share,
                    ),
                    const SizedBox(height: 10),
                    _buildStepRow(
                      context,
                      '២',
                      'អូសចុះក្រោម រួចជ្រើសរើស "បន្ថែមទៅអេក្រង់ដើម (Add to Home Screen)"',
                      CupertinoIcons.plus_square,
                    ),
                    const SizedBox(height: 10),
                    _buildStepRow(
                      context,
                      '៣',
                      'ចុច "បន្ថែម (Add)" នៅជ្រុងខាងស្តាំខាងលើ ជាការស្រេច!',
                      CupertinoIcons.checkmark_circle_fill,
                    ),
                  ] else ...[
                    _buildStepRow(
                      context,
                      '១',
                      'ចុចលើសញ្ញាចុចបី (Menu ⋮) នៅជ្រុងខាងស្តាំខាងលើនៃ Browser',
                      CupertinoIcons.ellipsis_vertical,
                    ),
                    const SizedBox(height: 10),
                    _buildStepRow(
                      context,
                      '២',
                      'ជ្រើសរើស "ដំឡើងកម្មវិធី (Install app)" ឬ "បន្ថែមទៅអេក្រង់ដើម"',
                      CupertinoIcons.arrow_down_to_line_alt,
                    ),
                    const SizedBox(height: 10),
                    _buildStepRow(
                      context,
                      '៣',
                      'ចុច "ដំឡើង (Install)" នោះរូប Spaces នឹងបង្ហាញលើទូរស័ព្ទភ្លាម!',
                      CupertinoIcons.checkmark_circle_fill,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Close button
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 13),
                color: isDark ? const Color(0xFF2C2F3E) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(14),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'យល់ព្រម / បិទ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(BuildContext context, String stepNum, String text, IconData icon) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withOpacity(isDark ? 0.25 : 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNum,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF007AFF),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AppTheme.primaryText,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Icon(icon, size: 16, color: AppTheme.secondaryText.withOpacity(0.7)),
      ],
    );
  }
}
