import 'package:flutter/cupertino.dart';
import '../services/theme_service.dart';
import '../utils/pwa_helper.dart';
import 'liquid_glass.dart';
import 'pwa_install_sheet.dart';

class PwaInstallBanner extends StatelessWidget {
  final bool compact;
  const PwaInstallBanner({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    // Only show on Web and when not already running as installed standalone PWA
    if (!PwaHelper.isWeb || PwaHelper.isStandalone()) {
      return const SizedBox.shrink();
    }

    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    if (compact) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minSize: 32,
        onPressed: () => PwaInstallSheet.show(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.25)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.device_phone_portrait, size: 14, color: Color(0xFF007AFF)),
              SizedBox(width: 5),
              Text(
                'ដំឡើង App',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF007AFF),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E212D).withOpacity(0.7) : const Color(0xFFEBF3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF007AFF).withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.device_phone_portrait,
                color: CupertinoColors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ដំឡើង Spaces លើទូរស័ព្ទ (PWA)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryText,
                  ),
                ),
                Text(
                  'បន្ថែមទៅ Home Screen ដំណើរការរហ័ស',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          LiquidGlassButton(
            label: 'ដំឡើង',
            icon: CupertinoIcons.arrow_down_circle_fill,
            onPressed: () => PwaInstallSheet.show(context),
            borderRadius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            fontSize: 12,
          ),
        ],
      ),
    );
  }
}
