import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  Locale _locale = const Locale('en', 'US');
  String _languageCode = 'en';
  bool _isRTL = false;

  Locale get locale => _locale;
  String get languageCode => _languageCode;
  bool get isRTL => _isRTL;

  // Supported languages
  final List<Map<String, dynamic>> languages = [
    {'code': 'en', 'name': 'English', 'nativeName': 'English', 'flag': '🇺🇸', 'locale': const Locale('en', 'US')},
    {'code': 'ar', 'name': 'Arabic', 'nativeName': 'العربية', 'flag': '🇪🇬', 'locale': const Locale('ar', 'EG'), 'isRTL': true},
    {'code': 'fr', 'name': 'French', 'nativeName': 'Français', 'flag': '🇫🇷', 'locale': const Locale('fr', 'FR')},
    {'code': 'es', 'name': 'Spanish', 'nativeName': 'Español', 'flag': '🇪🇸', 'locale': const Locale('es', 'ES')},
    {'code': 'de', 'name': 'German', 'nativeName': 'Deutsch', 'flag': '🇩🇪', 'locale': const Locale('de', 'DE')},
    {'code': 'it', 'name': 'Italian', 'nativeName': 'Italiano', 'flag': '🇮🇹', 'locale': const Locale('it', 'IT')},
    {'code': 'pt', 'name': 'Portuguese', 'nativeName': 'Português', 'flag': '🇵🇹', 'locale': const Locale('pt', 'PT')},
    {'code': 'ru', 'name': 'Russian', 'nativeName': 'Русский', 'flag': '🇷🇺', 'locale': const Locale('ru', 'RU')},
    {'code': 'zh', 'name': 'Chinese', 'nativeName': '中文', 'flag': '🇨🇳', 'locale': const Locale('zh', 'CN')},
    {'code': 'ja', 'name': 'Japanese', 'nativeName': '日本語', 'flag': '🇯🇵', 'locale': const Locale('ja', 'JP')},
    {'code': 'hi', 'name': 'Hindi', 'nativeName': 'हिन्दी', 'flag': '🇮🇳', 'locale': const Locale('hi', 'IN')},
    {'code': 'tr', 'name': 'Turkish', 'nativeName': 'Türkçe', 'flag': '🇹🇷', 'locale': const Locale('tr', 'TR')},
  ];

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguageCode = prefs.getString('language_code') ?? 'en';
      await setLanguage(savedLanguageCode);
    } catch (e) {
      print('Error loading language: $e');
    }
  }

  Future<void> setLanguage(String languageCode) async {
    final language = languages.firstWhere(
      (lang) => lang['code'] == languageCode,
      orElse: () => languages[0], // Default to English
    );

    _languageCode = languageCode;
    _locale = language['locale'] as Locale;
    _isRTL = language['isRTL'] as bool? ?? false;

    // Save to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', languageCode);
    } catch (e) {
      print('Error saving language: $e');
    }

    notifyListeners();
  }

  String getLanguageName(String code) {
    try {
      return languages.firstWhere((lang) => lang['code'] == code)['name'] as String;
    } catch (e) {
      return 'English';
    }
  }

  Map<String, dynamic>? getLanguageByCode(String code) {
    try {
      return languages.firstWhere((lang) => lang['code'] == code);
    } catch (e) {
      return languages[0];
    }
  }
}






















