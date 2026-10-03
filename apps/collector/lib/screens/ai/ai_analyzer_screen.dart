import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/ai_classification_service.dart';
import '../../services/image_service.dart';
import '../../services/lot_valuation.dart';
import '../../services/remote_ai_classification_service.dart';
import '../../widgets/ai_insight_card.dart';
import '../../widgets/custom_button.dart';
import '../lot/create_lot_args.dart';

/// In-app Gemini analyzer: photo → what it is, category, and collector tips.
class AiAnalyzerScreen extends StatefulWidget {
  const AiAnalyzerScreen({super.key});

  @override
  State<AiAnalyzerScreen> createState() => _AiAnalyzerScreenState();
}

class _AiAnalyzerScreenState extends State<AiAnalyzerScreen> {
  final ImageService _imageService = ImageService();
  final AiClassificationService _aiService =
      RemoteAiClassificationService(baseUrl: AppConstants.backendBaseUrl);

  String? _imagePath;
  bool _busy = false;
  bool _analyzing = false;
  bool _failed = false;
  ClassificationResult? _result;

  Future<void> _capture() async {
    setState(() => _busy = true);
    final picked = await _imageService.captureFromCamera();
    await _usePick(picked);
  }

  Future<void> _gallery() async {
    setState(() => _busy = true);
    final picked = await _imageService.pickFromGallery();
    await _usePick(picked);
  }

  Future<void> _usePick(ImagePickResult? picked) async {
    if (picked == null || kIsWeb) {
      setState(() => _busy = false);
      return;
    }
    final saved = await ImageService.saveImageToAppStorage(picked.xFile);
    final path = saved ?? picked.filePath;
    setState(() {
      _imagePath = path;
      _busy = false;
      _result = null;
      _failed = false;
    });
    if (path != null) await _analyze(path);
  }

  Future<void> _analyze(String path) async {
    setState(() {
      _analyzing = true;
      _failed = false;
    });
    final result = await _aiService.classifyEWasteImage(path);
    if (!mounted) return;
    setState(() {
      _analyzing = false;
      _result = result;
      _failed = result == null;
    });
  }

  void _createLot() {
    final result = _result;
    final auto = result != null && LotValuation.shouldAutoSelect(result);
    Navigator.pushNamed(
      context,
      '/create-lot',
      arguments: CreateLotArgs(
        imagePath: _imagePath,
        categoryId: auto ? result.categoryId : null,
        weightKg: auto ? result.weightKg : null,
        condition: auto ? result.condition : null,
        electronicDevice: result?.electronicDevice,
        shortDescription: result?.shortDescription,
        notes: result == null
            ? null
            : [
                if ((result.electronicDevice ?? '').trim().isNotEmpty)
                  result.electronicDevice!.trim(),
                if ((result.shortDescription ?? '').trim().isNotEmpty)
                  result.shortDescription!.trim(),
              ].join('. '),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('aiAnalyzerTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            loc.translate('aiAnalyzerSubtitle'),
            style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 220,
              color: Colors.black12,
              child: _imagePath != null
                  ? Image.file(File(_imagePath!), fit: BoxFit.cover, width: double.infinity)
                  : Center(
                      child: Text(
                        loc.translate('takePhotoPrompt'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (_analyzing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                ],
              ),
            ),
          if (_analyzing) Text(loc.translate('analyzingAi'), textAlign: TextAlign.center),
          if (_result != null) AiInsightCard(result: _result!),
          if (_failed) ...[
            Text(
              loc.translate('aiAnalysisFailed'),
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.orange.shade900),
            ),
            TextButton(
              onPressed: _imagePath == null ? null : () => _analyze(_imagePath!),
              child: Text(loc.translate('retryAi')),
            ),
          ],
          const SizedBox(height: 20),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else ...[
            CustomButton(
              label: loc.translate('takePhoto'),
              icon: Icons.camera_alt,
              onPressed: _capture,
            ),
            const SizedBox(height: 10),
            CustomButton(
              label: loc.translate('chooseGallery'),
              icon: Icons.photo_library,
              isSecondary: true,
              onPressed: _gallery,
            ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              CustomButton(
                label: loc.translate('saveAsLot'),
                icon: Icons.inventory_2_rounded,
                onPressed: _createLot,
              ),
              const SizedBox(height: 10),
              CustomButton(
                label: loc.translate('findRecycler'),
                icon: Icons.location_searching_rounded,
                isSecondary: true,
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/recyclers',
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
