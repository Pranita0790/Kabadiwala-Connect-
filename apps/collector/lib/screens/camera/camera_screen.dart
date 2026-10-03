import 'dart:io';
import 'dart:typed_data';
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

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImageService _imageService = ImageService();
  final AiClassificationService _aiService =
      RemoteAiClassificationService(baseUrl: AppConstants.backendBaseUrl);

  String? _capturedImagePath;
  List<int>? _capturedImageBytes;
  bool _isProcessing = false;
  bool _isAnalyzingAi = false;
  ClassificationResult? _aiResult;
  bool _aiFailed = false;

  Future<void> _takePhoto() async {
    setState(() => _isProcessing = true);
    final result = await _imageService.captureFromCamera();
    await _handlePickResult(result);
  }

  Future<void> _pickGallery() async {
    setState(() => _isProcessing = true);
    final result = await _imageService.pickFromGallery();
    await _handlePickResult(result);
  }

  Future<void> _handlePickResult(ImagePickResult? result) async {
    if (result == null) {
      setState(() => _isProcessing = false);
      return;
    }

    if (kIsWeb) {
      final bytes = await result.readBytes();
      setState(() {
        _capturedImageBytes = bytes;
        _capturedImagePath = null;
        _isProcessing = false;
        _aiResult = null;
        _aiFailed = false;
      });
      return;
    }

    final savedPath = await ImageService.saveImageToAppStorage(result.xFile);
    final path = savedPath ?? result.filePath;
    setState(() {
      _capturedImagePath = path;
      _isProcessing = false;
      _aiResult = null;
      _aiFailed = false;
    });
    if (path != null) {
      await _identifyWithGemini(path);
    }
  }

  Future<void> _identifyWithGemini(String path) async {
    setState(() {
      _isAnalyzingAi = true;
      _aiFailed = false;
    });
    final result = await _aiService.classifyEWasteImage(path);
    if (!mounted) return;
    setState(() {
      _isAnalyzingAi = false;
      _aiResult = result;
      _aiFailed = result == null;
    });
  }

  bool get _hasImage =>
      (kIsWeb && _capturedImageBytes != null) ||
      (!kIsWeb && _capturedImagePath != null);

  void _continueToLotCreation() {
    final result = _aiResult;
    final auto = result != null && LotValuation.shouldAutoSelect(result);
    Navigator.pushNamed(
      context,
      '/create-lot',
      arguments: CreateLotArgs(
        imagePath: kIsWeb ? null : _capturedImagePath,
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

  Widget _buildImagePreview(AppLocalizations loc) {
    if (kIsWeb && _capturedImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(
          Uint8List.fromList(_capturedImageBytes!),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    if (!kIsWeb && _capturedImagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(_capturedImagePath!),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.camera_alt_outlined, size: 80, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          loc.translate('takePhotoPrompt'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildAiCard(AppLocalizations loc) {
    if (_isAnalyzingAi) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(loc.translate('analyzingAi'))),
          ],
        ),
      );
    }

    if (_aiResult != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AiInsightCard(result: _aiResult!, compact: true),
      );
    }

    if (_aiFailed && _capturedImagePath != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade700),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.translate('aiAnalysisFailed'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _identifyWithGemini(_capturedImagePath!),
              child: Text(loc.translate('retryAi')),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('camera')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Card(
                color: Colors.black12,
                elevation: 3,
                child: Center(child: _buildImagePreview(loc)),
              ),
            ),
            const SizedBox(height: 16),
            if (_hasImage)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(child: _buildAiCard(loc)),
              ),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else if (_hasImage) ...[
              CustomButton(
                label: '${loc.translate('continueToDetails')} →',
                icon: Icons.arrow_forward_rounded,
                isLoading: _isAnalyzingAi,
                onPressed: _continueToLotCreation,
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: loc.translate('retakePhoto'),
                icon: Icons.refresh_rounded,
                isSecondary: true,
                onPressed: _takePhoto,
              ),
            ] else ...[
              CustomButton(
                label: loc.translate('takePhoto'),
                icon: kIsWeb ? Icons.photo_library : Icons.camera_alt,
                onPressed: _takePhoto,
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: loc.translate('chooseGallery'),
                icon: Icons.photo_library,
                isSecondary: true,
                onPressed: _pickGallery,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _continueToLotCreation,
                child: Text(
                  '${loc.translate('skipPhoto')} →',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
