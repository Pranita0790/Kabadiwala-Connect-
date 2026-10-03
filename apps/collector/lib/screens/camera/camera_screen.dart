import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/image_service.dart';
import '../../widgets/custom_button.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImageService _imageService = ImageService();

  /// The saved file path (native only)
  String? _capturedImagePath;

  /// Raw image bytes (used on web where File() is not supported)
  List<int>? _capturedImageBytes;

  bool _isProcessing = false;

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
      // On web, read bytes since File() is not supported
      final bytes = await result.readBytes();
      setState(() {
        _capturedImageBytes = bytes;
        _isProcessing = false;
      });
    } else {
      // On native, save to app storage and use file path
      final savedPath = await ImageService.saveImageToAppStorage(result.xFile);
      setState(() {
        _capturedImagePath = savedPath ?? result.filePath;
        _isProcessing = false;
      });
    }
  }

  bool get _hasImage =>
      (kIsWeb && _capturedImageBytes != null) ||
      (!kIsWeb && _capturedImagePath != null);

  /// Web has image bytes only — skip AI until a native file path exists.
  void _continueToLotCreation() {
    Navigator.pushNamed(
      context,
      '/create-lot',
      arguments: kIsWeb ? null : _capturedImagePath,
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
            // Image Preview Container
            Expanded(
              child: Card(
                color: Colors.black12,
                elevation: 3,
                child: Center(child: _buildImagePreview(loc)),
              ),
            ),
            const SizedBox(height: 24),

            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else if (_hasImage) ...[
              CustomButton(
                label: '${loc.translate('continueToDetails')} →',
                icon: Icons.arrow_forward_rounded,
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
