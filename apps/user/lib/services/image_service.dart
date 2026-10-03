import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImagePickResult {
  /// The local file path (native platforms only, null on web)
  final String? filePath;

  /// The raw bytes of the image (available on all platforms including web)
  final Future<List<int>> Function() readBytes;

  /// The original XFile from image_picker
  final XFile xFile;

  ImagePickResult({required this.xFile})
      : filePath = kIsWeb ? null : xFile.path,
        readBytes = xFile.readAsBytes;
}

class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// Opens the CAMERA to capture a photo.
  /// On desktop web, browsers fall back to the file picker because
  /// programmatic camera access requires getUserMedia (not available via image_picker).
  Future<ImagePickResult?> captureFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (photo == null) return null;
      return ImagePickResult(xFile: photo);
    } catch (_) {
      return null;
    }
  }

  /// Opens the GALLERY / file picker.
  Future<ImagePickResult?> pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (photo == null) return null;
      return ImagePickResult(xFile: photo);
    } catch (_) {
      return null;
    }
  }

  /// Saves the captured image to app's persistent storage directory (native only).
  /// On web this is a no-op and returns null.
  static Future<String?> saveImageToAppStorage(XFile xFile) async {
    if (kIsWeb) return null;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'lot_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final fileName = 'lot_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = await File(xFile.path).copy(p.join(imagesDir.path, fileName));
      return savedFile.path;
    } catch (_) {
      return xFile.path;
    }
  }
}
