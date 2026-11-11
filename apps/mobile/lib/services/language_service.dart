import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  final ValueNotifier<String> languageNotifier = ValueNotifier<String>('km');

  bool get isKhmer => languageNotifier.value == 'km';
  bool get isEnglish => languageNotifier.value == 'en';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('spaces_language') ?? 'km';
      languageNotifier.value = saved;
    } catch (e) {
      debugPrint('LanguageService init error: $e');
    }
  }

  Future<void> setLanguage(String lang) async {
    languageNotifier.value = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('spaces_language', lang);
    } catch (e) {
      debugPrint('LanguageService setLanguage error: $e');
    }
  }

  Future<void> toggleLanguage() async {
    final next = isKhmer ? 'en' : 'km';
    await setLanguage(next);
  }

  /// Helper to get text based on active language
  String t(String km, String en) {
    return isKhmer ? km : en;
  }
}

/// Global convenience function for translation
String tr(String km, String en) {
  return LanguageService().t(km, en);
}

