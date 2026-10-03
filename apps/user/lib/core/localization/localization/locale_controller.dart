import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class SupportedLanguage {
  final String code;
  final String nativeName;
  final String englishName;

  const SupportedLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
  });
}

/// Central controller for managing and persisting language preferences reactively.
class LocaleController extends ChangeNotifier {
  static LocaleController? _instance;
  final DatabaseService _dbService;

  Locale _locale = const Locale('en');
  bool _isInitialized = false;

  static const List<SupportedLanguage> supportedLanguages = [
    SupportedLanguage(code: 'en', nativeName: 'English', englishName: 'English'),
    SupportedLanguage(code: 'hi', nativeName: 'हिंदी', englishName: 'Hindi'),
    SupportedLanguage(code: 'mr', nativeName: 'मराठी', englishName: 'Marathi'),
  ];

  static String normalizeCode(String? code) {
    if (code == null) return 'en';
    final normalized = code.toLowerCase().trim();
    if (normalized.startsWith('hi')) return 'hi';
    if (normalized.startsWith('mr')) return 'mr';
    return 'en';
  }

  LocaleController({DatabaseService? dbService, Locale? initialLocale})
      : _dbService = dbService ?? DatabaseService.instance {
    if (initialLocale != null) {
      _locale = Locale(normalizeCode(initialLocale.languageCode));
      _isInitialized = true;
    }
  }

  static LocaleController get instance {
    _instance ??= LocaleController();
    return _instance!;
  }

  Locale get currentLocale => _locale;
  String get currentLanguageCode => _locale.languageCode;
  bool get isInitialized => _isInitialized;

  /// Loads the persisted language preference from local SQLite storage
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final savedLang = await _dbService.getLanguagePreference(defaultLanguage: 'en');
      _locale = Locale(normalizeCode(savedLang));
    } catch (_) {
      _locale = const Locale('en');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Changes the application language and immediately persists to SQLite
  Future<void> setLanguageCode(String languageCode) async {
    final normalized = normalizeCode(languageCode);
    if (_locale.languageCode == normalized) return;
    _locale = Locale(normalized);
    notifyListeners();

    try {
      await _dbService.saveLanguagePreference(normalized);
    } catch (_) {}
  }

  Future<void> setLocale(Locale newLocale) async {
    await setLanguageCode(newLocale.languageCode);
  }
}
