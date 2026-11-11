import 'package:flutter/material.dart';
import 'api_service.dart';

class AppTheme {
  static bool get isDark => ApiService().isDarkModeNotifier.value;

  static Color get accentBlue => isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  static Color get accentCyan => isDark ? const Color(0xFF64D2FF) : const Color(0xFF00B4D8);
  static Color get accentIndigo => isDark ? const Color(0xFF7D7AFF) : const Color(0xFF5856D6);
  static Color get accentCrimson => isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30);
  static Color get accentGreen => isDark ? const Color(0xFF30D158) : const Color(0xFF34C759);

  static Color get scaffoldBg => isDark ? const Color(0xFF05070C) : const Color(0xFFF2F5FA);
  static Color get surfaceBg => isDark ? const Color(0xFF0E131D) : const Color(0xFFFFFFFF);
  static Color get cardBg =>
      isDark ? const Color(0xFF131926).withValues(alpha: 0.78) : Colors.white.withValues(alpha: 0.78);
  static Color get modalBg =>
      isDark ? const Color(0xFF101622).withValues(alpha: 0.90) : const Color(0xFFF6F9FF).withValues(alpha: 0.92);
  static Color get fieldBg =>
      isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFF0F172A).withValues(alpha: 0.055);
  static Color get navBarBg =>
      isDark ? const Color(0xFF0D121C).withValues(alpha: 0.76) : Colors.white.withValues(alpha: 0.78);

  static Color get primaryText => isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color get secondaryText => isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  static Color get tertiaryText => isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  static Color get border =>
      isDark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.80);
  static Color get cardBorder =>
      isDark ? Colors.white.withValues(alpha: 0.13) : const Color(0xFFCBD5E1).withValues(alpha: 0.65);
  static Color get divider =>
      isDark ? Colors.white.withValues(alpha: 0.09) : const Color(0xFF94A3B8).withValues(alpha: 0.20);

  // Apple iOS 26 Liquid Glass Tokens
  static Color get glassBg =>
      isDark ? const Color(0xFF161D2C).withValues(alpha: 0.66) : Colors.white.withValues(alpha: 0.68);
  static Color get glassElevatedBg =>
      isDark ? const Color(0xFF1E273B).withValues(alpha: 0.80) : Colors.white.withValues(alpha: 0.86);
  static Color get glassPillBg =>
      isDark ? Colors.white.withValues(alpha: 0.09) : Colors.white.withValues(alpha: 0.62);
  static Color get glassActivePillBg =>
      isDark ? accentBlue.withValues(alpha: 0.28) : accentBlue.withValues(alpha: 0.14);
  static Color get glassSpecularTop =>
      isDark ? Colors.white.withValues(alpha: 0.24) : Colors.white.withValues(alpha: 0.96);
  static Color get glassSpecularBottom =>
      isDark ? Colors.black.withValues(alpha: 0.40) : const Color(0xFF94A3B8).withValues(alpha: 0.26);
  static Color get glassShadow =>
      isDark ? Colors.black.withValues(alpha: 0.45) : const Color(0xFF1E293B).withValues(alpha: 0.08);
  static List<Color> get ambientBgColors => isDark
      ? const [Color(0xFF04060A), Color(0xFF0A1020), Color(0xFF05080F)]
      : const [Color(0xFFF3F6FC), Color(0xFFE9F0FF), Color(0xFFF4F7FC)];
}
