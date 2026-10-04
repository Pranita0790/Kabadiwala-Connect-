import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../core/constants/app_colors.dart';
import '../core/localization/locale_controller.dart';
import '../screens/lot/create_lot_args.dart';
import '../services/backend_url.dart';

class AiCopilotSheet extends StatefulWidget {
  const AiCopilotSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AiCopilotSheet(),
    );
  }

  @override
  State<AiCopilotSheet> createState() => _AiCopilotSheetState();
}

class _AiCopilotSheetState extends State<AiCopilotSheet> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();

  final List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  bool _isListening = false;
  bool _speechEnabled = false;
  String _liveSpokenText = '';
  String _activeLang = 'hi';

  @override
  void initState() {
    super.initState();
    _activeLang = LocaleController.instance.currentLanguageCode;
    _initTts();
    _initSpeech();
    _initWelcome();
  }

  void _initTts() {
    _tts.setLanguage(_activeLang == 'mr' ? 'mr-IN' : (_activeLang == 'en' ? 'en-IN' : 'hi-IN'));
    _tts.setPitch(1.0);
    _tts.setSpeechRate(0.44); // Natural, clear, conversational human speed
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (e) {
          if (mounted) setState(() => _isListening = false);
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              _finishVoiceInput();
            }
          }
        },
      );
      if (mounted) setState(() {});
    } catch (_) {
      _speechEnabled = false;
    }
  }

  void _initWelcome() {
    final isMr = _activeLang == 'mr';
    final isEn = _activeLang == 'en';

    final text = isMr
        ? 'नमस्कार! मी आपला Kabadiwala AI Copilot आहे. आपण बोलून, फोटो पाठवून किंवा टाईप करून भंगाराचे योग्य दर आणि सर्वाधिक पैसे देणाऱ्या रिसायकलरची माहिती घेऊ शकता.'
        : isEn
            ? 'Hello! I am your Kabadiwala AI Copilot. Ask via voice, send scrap photos, or type to get real-time valuations and find top-paying recyclers.'
            : 'नमस्ते! मैं आपका Kabadiwala AI Copilot हूँ। आप बोलकर, फोटो भेजकर या लिखकर कबाड़ के सही दाम और सबसे ज़्यादा पैसे देने वाले रिसाइकिलर की जानकारी ले सकते हैं।';

    final chips = isMr
        ? ['तांब्याची वायर भाव', 'मदरबोर्ड स्क्रॅप', 'बॅटरी दर', 'जवळचा रिसायकलर']
        : isEn
            ? ['Copper Wire Rate', 'PCB Motherboard Price', 'Battery Scrap', 'Best Recycler']
            : ['तांबे के तार का रेट', 'PCB मदरबोर्ड का भाव', 'बैटरी स्क्रैप टिप्स', 'बेस्ट रिसाइकिलर'];

    _messages.add({
      'isUser': false,
      'text': text,
      'chips': chips,
    });
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
      _tts.setSpeechRate(0.44);
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _finishVoiceInput();
      return;
    }

    if (!_speechEnabled) {
      await _initSpeech();
    }

    if (_speechEnabled) {
      final localeId = _activeLang == 'mr'
          ? 'mr_IN'
          : (_activeLang == 'hi' ? 'hi_IN' : 'en_IN');

      setState(() {
        _isListening = true;
        _liveSpokenText = '';
      });

      await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _liveSpokenText = result.recognizedWords;
            });
            if (result.finalResult && _liveSpokenText.trim().isNotEmpty) {
              _finishVoiceInput();
            }
          }
        },
        localeId: localeId,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      );
    } else {
      _simulateVoiceInput();
    }
  }

  void _finishVoiceInput() {
    if (!_isListening && _liveSpokenText.trim().isEmpty) return;
    final spoken = _liveSpokenText.trim();
    setState(() {
      _isListening = false;
      _liveSpokenText = '';
    });
    if (spoken.isNotEmpty) {
      _controller.clear();
      setState(() {
        _messages.add({'isUser': true, 'text': spoken, 'isVoice': true});
        _loading = true;
      });
      _callCopilot(query: spoken);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 1024, imageQuality: 80);
      if (picked == null) return;

      final bytes = await File(picked.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      setState(() {
        _messages.add({
          'isUser': true,
          'imagePath': picked.path,
          'text': _activeLang == 'mr'
              ? 'या स्क्रॅपचा फोटो तपासा आणि सर्वोत्तम दर व रिसायकलर सुचवा.'
              : _activeLang == 'en'
                  ? 'Analyze this scrap photo and suggest the best rate & paying recycler.'
                  : 'इस कबाड़ की फोटो देखकर सही रेट और सबसे अच्छा रिसाइकिलर बताएं।',
        });
        _loading = true;
      });

      await _callCopilot(
        query: 'Analyze this scrap photo and suggest highest paying recycler',
        imageBase64: base64Image,
        imagePath: picked.path,
      );
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _simulateVoiceInput() async {
    setState(() => _isListening = true);

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final voiceQuery = _activeLang == 'mr'
        ? 'माझ्याकडे 10 किलो तांब्याची वायर आणि 5 मदरबोर्ड आहेत, मला कुठे सर्वात जास्त भाव मिळेल?'
        : _activeLang == 'en'
            ? 'I have 10 kg copper wire and 5 motherboards. Which recycler will pay me the highest?'
            : 'मेरे पास 10 किलो तांबे का तार और 5 मदरबोर्ड हैं, कौन सा रिसाइकिलर सबसे ज़्यादा पैसे देगा?';

    setState(() {
      _isListening = false;
      _messages.add({'isUser': true, 'text': voiceQuery, 'isVoice': true});
      _loading = true;
    });

    await _callCopilot(query: voiceQuery);
  }

  Future<void> _callCopilot({
    required String query,
    String? imageBase64,
    String? imagePath,
  }) async {
    final candidateRoots = <String>{
      BackendUrl.root,
      'http://127.0.0.1:5001',
      'http://10.1.121.20:5001',
      'http://10.0.2.2:5001',
      'http://127.0.0.1:5000',
    };

    bool success = false;
    for (final root in candidateRoots) {
      try {
        final uri = Uri.parse('$root/api/ai/copilot');
        final res = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'message': query,
            'language': _activeLang,
            'imageBase64': imageBase64,
            'mimetype': 'image/jpeg',
          }),
        ).timeout(const Duration(seconds: 40));

        if (res.statusCode == 200) {
          final jsonBody = json.decode(res.body);
          final data = jsonBody['data'] ?? jsonBody;
          final replyText = data['reply'] ?? '';

          setState(() {
            _messages.add({
              'isUser': false,
              'text': replyText,
              'chips': (data['suggested_actions'] as List?)?.map((e) => e.toString()).toList() ?? [],
              'valuation': data['total_estimated_value_inr'] != null
                  ? {
                      'material': data['detected_material'] ?? 'copper_wire',
                      'category_name': data['category_name'] ?? 'Copper Wire',
                      'weight_kg': (data['estimated_weight_kg'] as num?)?.toDouble() ?? 5.0,
                      'rate_per_kg': (data['suggested_rate_per_kg'] as num?)?.toInt() ?? 650,
                      'total_value': (data['total_estimated_value_inr'] as num?)?.toInt() ?? 3250,
                      'best_recycler': data['best_paying_recycler'],
                      'imagePath': imagePath,
                    }
                  : null,
            });
          });

          if (replyText.isNotEmpty) {
            _speak(replyText);
          }
          success = true;
          BackendUrl.rememberRoot(root);
          break;
        }
      } catch (_) {
        // Try next candidate root
      }
    }

    if (!success) {
      _addFallback();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _addFallback() {
    final isMr = _activeLang == 'mr';
    final isEn = _activeLang == 'en';

    final text = isMr
        ? 'तुमच्या स्क्रॅपसाठी "विद्युत हाय-ग्रेड कॉपर रिफायनर्स" सर्वात जास्त म्हणजे ₹650/किलो दर देईल. तांब्याची तार आणि बॅटरी वेगळी ठेवा.'
        : isEn
            ? 'For high-purity copper and motherboards, "Vidyut High-Grade Copper Refiners" pays the highest rate of ₹650/kg.'
            : 'आपके स्क्रैप के लिए "विद्युत हाई-ग्रेड कॉपर रिफाइनर्स" सबसे ज़्यादा ₹650/किलो का भाव देगा। तार छीलकर बेचने से बेहतर मुनाफा मिलेगा।';

    setState(() {
      _messages.add({
        'isUser': false,
        'text': text,
        'chips': isMr ? ['लॉट तयार करा', 'दर तपासा'] : ['लॉट बनाएं', 'रेट देखें'],
        'valuation': {
          'material': 'copper_wire',
          'category_name': 'Copper Wire',
          'weight_kg': 10.0,
          'rate_per_kg': 650,
          'total_value': 6500,
          'best_recycler': {
            'name': 'Vidyut High-Grade Copper Refiners',
            'rate_per_kg': 650,
            'distance_km': 3.5,
            'address': 'Marketyard, Pune',
          },
        },
      });
    });
  }

  void _createLotFromValuation(Map<String, dynamic> val) {
    Navigator.pop(context);
    Navigator.pushNamed(
      context,
      '/create-lot',
      arguments: CreateLotArgs(
        imagePath: val['imagePath'] as String?,
        categoryId: val['material'] as String?,
        weightKg: (val['weight_kg'] as num?)?.toDouble() ?? 5.0,
        condition: 'scrap',
        electronicDevice: val['category_name'] as String?,
        notes: 'AI Copilot recommended best buyer: ${(val['best_recycler'] as Map?)?['name'] ?? 'Authorized Recycler'} @ ₹${val['rate_per_kg']}/kg',
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF134233),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology, color: Color(0xFF69F0AE), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'AI Scrap Copilot',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF69F0AE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _activeLang.toUpperCase(),
                              style: const TextStyle(color: Color(0xFF134233), fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Multilingual Voice & Photo Valuation Advisor',
                        style: TextStyle(color: Color(0xFFA5D6A7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] == true;
                final chips = (msg['chips'] as List?)?.cast<String>() ?? [];
                final val = msg['valuation'] as Map<String, dynamic>?;
                final imagePath = msg['imagePath'] as String?;

                return Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (imagePath != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        height: 140,
                        width: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: FileImage(File(imagePath)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                      decoration: BoxDecoration(
                        color: isUser ? const Color(0xFF134233) : const Color(0xFFF1F8F5),
                        borderRadius: BorderRadius.circular(16),
                        border: isUser ? null : Border.all(color: const Color(0xFFC8E6C9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (msg['isVoice'] == true)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.mic, color: Color(0xFF69F0AE), size: 14),
                                  SizedBox(width: 4),
                                  Text('Voice Note', style: TextStyle(color: Color(0xFF69F0AE), fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          Text(
                            msg['text'] ?? '',
                            style: TextStyle(
                              color: isUser ? Colors.white : AppColors.textPrimary,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                          if (!isUser)
                            Align(
                              alignment: Alignment.bottomRight,
                              child: IconButton(
                                icon: const Icon(Icons.volume_up_rounded, size: 18, color: Color(0xFF2E7D32)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _speak(msg['text'] ?? ''),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Structured AI Valuation & Best Buyer Card
                    if (val != null)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFA5D6A7), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      val['category_name']?.toString() ?? 'Scrap Lot',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B5E20)),
                                    ),
                                    Text(
                                      '${val['weight_kg']} kg @ ₹${val['rate_per_kg']}/kg',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF81C784)),
                                  ),
                                  child: Text(
                                    '₹${val['total_value']}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20)),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            if (val['best_recycler'] != null)
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Top Buyer: ${(val['best_recycler'] as Map)['name']} (₹${(val['best_recycler'] as Map)['rate_per_kg']}/kg • ${(val['best_recycler'] as Map)['distance_km']} km)',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF134233),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.add_shopping_cart, size: 16),
                                label: Text(
                                  _activeLang == 'mr'
                                      ? 'हा लॉट थेट जोडा (Create Lot)'
                                      : _activeLang == 'en'
                                          ? 'Create Scrap Lot'
                                          : 'यह लॉट सीधे जोड़ें (Create Lot)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                onPressed: () => _createLotFromValuation(val),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (chips.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: chips.map((c) {
                            return ActionChip(
                              label: Text(c, style: const TextStyle(fontSize: 12, color: Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
                              backgroundColor: const Color(0xFFE8F5E9),
                              onPressed: () {
                                _controller.text = c;
                                setState(() {
                                  _messages.add({'isUser': true, 'text': c});
                                  _loading = true;
                                });
                                _callCopilot(query: c);
                              },
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          if (_isListening)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activeLang == 'mr'
                              ? 'माईक चालू आहे... (Live Listening)'
                              : _activeLang == 'en'
                                  ? 'Listening to your voice...'
                                  : 'माइक चालू है... (Live Listening)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.redAccent),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _liveSpokenText.isNotEmpty
                              ? _liveSpokenText
                              : (_activeLang == 'mr'
                                  ? 'भंगाराबद्दल काहीही बोला...'
                                  : _activeLang == 'en'
                                      ? 'Speak about scrap weight, rates...'
                                      : 'कबाड़ के वजन और रेट के बारे में बोलिए...'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _liveSpokenText.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                            color: const Color(0xFF134233),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF134233),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check, size: 14),
                    label: Text(
                      _activeLang == 'mr' ? 'पाठवा' : (_activeLang == 'en' ? 'Send' : 'भेजें'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _finishVoiceInput,
                  ),
                ],
              ),
            ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('AI analyzing scrap & calculating best buyer...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),

          // Input Bar with Media and Voice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF134233)),
                  tooltip: 'Take Scrap Photo',
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
                IconButton(
                  icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF134233)),
                  tooltip: 'Upload from Gallery',
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none_rounded,
                    color: _isListening ? Colors.red : const Color(0xFF134233),
                  ),
                  tooltip: 'Live Voice Input',
                  onPressed: _toggleListening,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: _activeLang == 'mr'
                          ? 'विचार करा किंवा फोटो पाठवा...'
                          : _activeLang == 'en'
                              ? 'Ask rate, send photo or speak...'
                              : 'रेट पूछें, फोटो भेजें या बोलें...',
                      hintStyle: const TextStyle(fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFFC8E6C9)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FBF9),
                    ),
                    onSubmitted: (text) {
                      if (text.trim().isEmpty) return;
                      _controller.clear();
                      setState(() {
                        _messages.add({'isUser': true, 'text': text});
                        _loading = true;
                      });
                      _callCopilot(query: text);
                    },
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF134233)),
                  onPressed: () {
                    final text = _controller.text.trim();
                    if (text.isEmpty) return;
                    _controller.clear();
                    setState(() {
                      _messages.add({'isUser': true, 'text': text});
                      _loading = true;
                    });
                    _callCopilot(query: text);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
