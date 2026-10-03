import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Service responsible for Text-To-Speech (TTS) audio playback.
///
/// Designed to be completely independent of the UI layer.
/// Supports English (`en-IN`), Hindi (`hi-IN`), and Marathi (`mr-IN`).
class AudioService {
  static AudioService? _instance;
  final FlutterTts _flutterTts;
  bool _isSpeaking = false;
  
  // Test mock override
  bool isTestMode = false;
  String? lastSpokenText;
  String? lastSpokenLanguage;

  final StreamController<bool> _speakingStateController =
      StreamController<bool>.broadcast();

  AudioService({FlutterTts? tts, this.isTestMode = false})
      : _flutterTts = tts ?? FlutterTts() {
    if (!isTestMode) {
      _initTts();
    }
  }

  factory AudioService.getInstance() {
    _instance ??= AudioService();
    return _instance!;
  }

  static AudioService get instance => AudioService.getInstance();

  static void setInstance(AudioService service) {
    _instance = service;
  }

  bool get isSpeaking => _isSpeaking;
  Stream<bool> get onSpeakingStateChanged => _speakingStateController.stream;

  void _initTts() {
    try {
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        if (!_speakingStateController.isClosed) {
          _speakingStateController.add(true);
        }
      });
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        if (!_speakingStateController.isClosed) {
          _speakingStateController.add(false);
        }
      });
      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        if (!_speakingStateController.isClosed) {
          _speakingStateController.add(false);
        }
      });
      _flutterTts.setErrorHandler((dynamic msg) {
        _isSpeaking = false;
        if (!_speakingStateController.isClosed) {
          _speakingStateController.add(false);
        }
      });
    } catch (e) {
      debugPrint('TTS initialization notice: $e');
    }
  }

  /// Formulates human-like spoken sentences for price announcements.
  ///
  /// Examples:
  /// - English: "PCB. Two hundred forty to two hundred ninety rupees per kilogram."
  /// - Hindi: "पीसीबी. दो सौ चालीस से दो सौ नब्बे रुपये प्रति किलोग्राम।"
  /// - Marathi: "पीसीबी. दोनशे चाळीस ते दोनशे नव्वद रुपये प्रति किलो."
  String generatePriceSpeechText({
    required String material,
    required double minPrice,
    required double maxPrice,
    required String unit,
    required String languageCode,
  }) {
    final minInt = minPrice.round();
    final maxInt = maxPrice.round();

    switch (languageCode) {
      case 'hi':
        final minWords = numberToHindiWords(minInt);
        final maxWords = numberToHindiWords(maxInt);
        final unitName = unit.toLowerCase() == 'kg' ? 'किलोग्राम' : 'नग';
        return '$material. $minWords से $maxWords रुपये प्रति $unitName।';

      case 'mr':
        final minWords = numberToMarathiWords(minInt);
        final maxWords = numberToMarathiWords(maxInt);
        final unitName = unit.toLowerCase() == 'kg' ? 'किलो' : 'नग';
        return '$material. $minWords ते $maxWords रुपये प्रति $unitName.';

      case 'en':
      default:
        final minWords = numberToEnglishWords(minInt);
        final maxWords = numberToEnglishWords(maxInt);
        final unitName = unit.toLowerCase() == 'kg' ? 'kilogram' : 'item';
        return '$material. $minWords to ${maxWords.toLowerCase()} rupees per $unitName.';
    }
  }

  /// Speaks the price range text using TTS.
  Future<void> speakPriceRange({
    required String material,
    required double minPrice,
    required double maxPrice,
    required String unit,
    required String languageCode,
  }) async {
    final speechText = generatePriceSpeechText(
      material: material,
      minPrice: minPrice,
      maxPrice: maxPrice,
      unit: unit,
      languageCode: languageCode,
    );

    await speak(speechText, languageCode: languageCode);
  }

  /// Dispatches speech text to the TTS engine with appropriate language locale.
  Future<void> speak(String text, {required String languageCode}) async {
    await stop();

    lastSpokenText = text;
    lastSpokenLanguage = languageCode;

    if (isTestMode) {
      _isSpeaking = true;
      if (!_speakingStateController.isClosed) {
        _speakingStateController.add(true);
      }
      return;
    }

    try {
      String ttsLocale;
      switch (languageCode) {
        case 'hi':
          ttsLocale = 'hi-IN';
          break;
        case 'mr':
          ttsLocale = 'mr-IN';
          break;
        case 'en':
        default:
          ttsLocale = 'en-IN';
          break;
      }

      await _flutterTts.setLanguage(ttsLocale);
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  Future<void> stop() async {
    if (_isSpeaking) {
      if (!isTestMode) {
        try {
          await _flutterTts.stop();
        } catch (_) {}
      }
      _isSpeaking = false;
      if (!_speakingStateController.isClosed) {
        _speakingStateController.add(false);
      }
    }
  }

  void dispose() {
    _speakingStateController.close();
  }

  // ===========================================================================
  // NUMBER TO WORDS UTILITIES (English, Hindi, Marathi)
  // ===========================================================================

  static String numberToEnglishWords(int n) {
    if (n == 0) return 'Zero';
    if (n < 0) return 'minus ${numberToEnglishWords(-n)}';

    const units = [
      '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
      'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
      'seventeen', 'eighteen', 'nineteen'
    ];
    const tens = [
      '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'
    ];

    String words = '';

    if ((n ~/ 1000) > 0) {
      words += '${numberToEnglishWords(n ~/ 1000)} thousand ';
      n %= 1000;
    }

    if ((n ~/ 100) > 0) {
      words += '${units[n ~/ 100]} hundred ';
      n %= 100;
    }

    if (n > 0) {
      if (n < 20) {
        words += units[n];
      } else {
        words += tens[n ~/ 10];
        if ((n % 10) > 0) {
          words += ' ${units[n % 10]}';
        }
      }
    }

    final trimmed = words.trim();
    if (trimmed.isEmpty) return 'Zero';
    // Capitalize first letter
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  static String numberToHindiWords(int n) {
    if (n == 0) return 'शून्य';
    if (n < 0) return 'माइनस ${numberToHindiWords(-n)}';

    const hindiNumbers = {
      1: 'एक', 2: 'दो', 3: 'तीन', 4: 'चार', 5: 'पांच', 6: 'छह', 7: 'सात', 8: 'आठ', 9: 'नौ', 10: 'दस',
      11: 'ग्यारह', 12: 'बारह', 13: 'तेरह', 14: 'चौदह', 15: 'पंद्रह', 16: 'सोलह', 17: 'सत्रह', 18: 'अठारह', 19: 'उन्नीस', 20: 'बीस',
      21: 'इक्कीस', 22: 'बाईस', 23: 'तेईस', 24: 'चौबीस', 25: 'पच्चीस', 26: 'छब्बीस', 27: 'सत्ताईस', 28: 'अट्ठाईस', 29: 'उनतीस', 30: 'तीस',
      31: 'इकतीस', 32: 'बत्तीस', 33: 'तैंतीस', 34: 'चौंतीस', 35: 'पैंतीस', 36: 'छत्तीस', 37: 'सैंतीस', 38: 'अड़तीस', 39: 'उनतालीस', 40: 'चालीस',
      41: 'इकतालीस', 42: 'बयालीस', 43: 'तैंतालीस', 44: 'चवालीस', 45: 'पैंतालीस', 46: 'छियालीस', 47: 'सैंतालीस', 48: 'अड़तालीस', 49: 'उनचास', 50: 'पचास',
      51: 'इक्यावन', 52: 'बावन', 53: 'तिरपन', 54: 'चौवन', 55: 'पचपन', 56: 'छप्पन', 57: 'सत्तावन', 58: 'अट्ठावन', 59: 'उनसठ', 60: 'साठ',
      61: 'इकसठ', 62: 'बासठ', 63: 'तिरसठ', 64: 'चौंसठ', 65: 'पैंसठ', 66: 'छियासठ', 67: 'सरसठ', 68: 'अड़सठ', 69: 'उनहत्तर', 70: 'सत्तर',
      71: 'इकहत्तर', 72: 'बहत्तर', 73: 'तिहत्तर', 74: 'चौहत्तर', 75: 'पचहत्तर', 76: 'छिहत्तर', 77: 'सतहत्तर', 78: 'अठहत्तर', 79: 'उन्नासी', 80: 'अस्सी',
      81: 'इक्यासी', 82: 'बयासी', 83: 'तिरासी', 84: 'चौरासी', 85: 'पचासी', 86: 'छियासी', 87: 'सत्तासी', 88: 'अट्ठासी', 89: 'नवासी', 90: 'नब्बे',
      91: 'इक्यानवे', 92: 'बानवे', 93: 'तिरानवे', 94: 'चौरानवे', 95: 'पंचानवे', 96: 'छियानवे', 97: 'सत्तानवे', 98: 'अट्ठानवे', 99: 'निन्यानवे',
    };

    String words = '';

    if ((n ~/ 1000) > 0) {
      final th = n ~/ 1000;
      words += '${hindiNumbers[th] ?? numberToHindiWords(th)} हजार ';
      n %= 1000;
    }

    if ((n ~/ 100) > 0) {
      final h = n ~/ 100;
      words += '${hindiNumbers[h] ?? numberToHindiWords(h)} सौ ';
      n %= 100;
    }

    if (n > 0) {
      words += hindiNumbers[n] ?? '$n';
    }

    return words.trim();
  }

  static String numberToMarathiWords(int n) {
    if (n == 0) return 'शून्य';
    if (n < 0) return 'मायनस ${numberToMarathiWords(-n)}';

    const marathiHundreds = {
      1: 'एकशे', 2: 'दोनशे', 3: 'तीनशे', 4: 'चारशे', 5: 'पाचशे', 6: 'सहाशे', 7: 'सातशे', 8: 'आठशे', 9: 'नऊशे'
    };

    const marathiNumbers = {
      1: 'एक', 2: 'दोन', 3: 'तीन', 4: 'चार', 5: 'पाच', 6: 'सहा', 7: 'सात', 8: 'आठ', 9: 'नऊ', 10: 'दहा',
      11: 'अकरा', 12: 'बारा', 13: 'तेरा', 14: 'चौदा', 15: 'पंधरा', 16: 'सोळा', 17: 'सतरा', 18: 'अठरा', 19: 'एकोणीस', 20: 'वीस',
      21: 'एकवीस', 22: 'बावीस', 23: 'तेवीस', 24: 'चोवीस', 25: 'पंचवीस', 26: 'सव्वीस', 27: 'सत्तावीस', 28: 'अठ्ठावीस', 29: 'एकोणतीस', 30: 'तीस',
      31: 'एकतीस', 32: 'बत्तीस', 33: 'तेहेतीस', 34: 'चौतीस', 35: 'पस्तीस', 36: 'छत्तीस', 37: 'सदतीस', 38: 'अडतीस', 39: 'एकोणचाळीस', 40: 'चाळीस',
      41: 'एक्केचाळीस', 42: 'बेचाळीस', 43: 'त्रेचाळीस', 44: 'चव्वेचाळीस', 45: 'पंचेचाळीस', 46: 'शेहेचाळीस', 47: 'सत्तेचाळीस', 48: 'अठ्ठेचाळीस', 49: 'एकोणपन्नास', 50: 'पन्नास',
      51: 'एक्कावन्न', 52: 'बावन्न', 53: 'त्रेपन्न', 54: 'चौपन्न', 55: 'पंचावन्न', 56: 'छप्पन्न', 57: 'सत्तावन्न', 58: 'अठ्ठावन्न', 59: 'एकोणसाठ', 60: 'साठ',
      61: 'एकसष्ठ', 62: 'बासष्ठ', 63: 'त्रेसष्ठ', 64: 'चौसष्ठ', 65: 'पासष्ठ', 66: 'सहासष्ठ', 67: 'सदुसष्ठ', 68: 'अडुसष्ठ', 69: 'एकोणसत्तर', 70: 'सत्तर',
      71: 'एक्काहत्तर', 72: 'बाहत्तर', 73: 'त्र्याहत्तर', 74: 'चौहत्तर', 75: 'पंच्याहत्तर', 76: 'शहात्तर', 77: 'सत्त्याहत्तर', 78: 'अठ्ठ्याहत्तर', 79: 'एकोणऐंशी', 80: 'ऐंशी',
      81: 'एक्क्याऐंशी', 82: 'ब्याऐंशी', 83: 'त्र्याऐंशी', 84: 'चौऱ्याऐंशी', 85: 'पंच्याऐंशी', 86: 'शहाऐंशी', 87: 'सत्त्याऐंशी', 88: 'अठ्ठ्याऐंशी', 89: 'एकोणनव्वद', 90: 'नव्वद',
      91: 'एक्क्याण्णव', 92: 'ब्याण्णव', 93: 'त्र्याण्णव', 94: 'चौऱ्याण्णव', 95: 'पंच्याण्णव', 96: 'शहाण्णव', 97: 'सत्त्याण्णव', 98: 'अठ्ठ्याण्णव', 99: 'नव्व्याण्णव',
    };

    String words = '';

    if ((n ~/ 1000) > 0) {
      final th = n ~/ 1000;
      words += '${marathiNumbers[th] ?? "$th"} हजार ';
      n %= 1000;
    }

    if ((n ~/ 100) > 0) {
      final h = n ~/ 100;
      words += '${marathiHundreds[h] ?? "$h शे"} ';
      n %= 100;
    }

    if (n > 0) {
      words += marathiNumbers[n] ?? '$n';
    }

    return words.trim();
  }
}
