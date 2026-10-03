import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../core/constants/app_constants.dart';
import 'ai_classification_service.dart';

/// Calls the Node.js backend AI gateway for e-waste classification.
/// Architecture: Flutter → Node.js Backend → FastAPI AI Service → MobileNetV3
/// Flutter never calls the Python AI service directly.
class RemoteAiClassificationService implements AiClassificationService {
  final String baseUrl;
  final http.Client _client;

  RemoteAiClassificationService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? AppConstants.backendBaseUrl,
        _client = client ?? http.Client();

  @override
  Future<ClassificationResult?> classifyEWasteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        developer.log('Image file does not exist: $imagePath', name: 'ai.classify');
        return null;
      }

      final filename = path.basename(imagePath);
      final contentType = _contentTypeForPath(imagePath);

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/ai/analyze'),
      );

      // http 1.x defaults missing contentType to application/octet-stream,
      // which the backend rejects as UNSUPPORTED_MEDIA_TYPE.
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imagePath,
          filename: filename,
          contentType: contentType,
        ),
      );

      // 30s timeout accounts for Flutter→Node→FastAPI two-hop latency
      final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResult = json.decode(response.body);

        final material = jsonResult['material'] as String?;
        final confidence = (jsonResult['confidence'] as num?)?.toDouble() ?? 0.0;

        if (material != null) {
          final categoryId = _mapMaterialToCategoryId(material);
          final weightKg = _parseWeightKg(jsonResult);
          final condition = jsonResult['suggested_condition'] as String?;
          return ClassificationResult(
            categoryId: categoryId,
            categoryName: material,
            confidenceScore: confidence,
            isMockResult: false,
            weightKg: weightKg,
            condition: _mapCondition(condition),
          );
        }
      } else {
        developer.log(
          'Failed to analyze image: ${response.statusCode}',
          name: 'ai.classify',
          error: response.body,
        );
      }
    } catch (e) {
      developer.log('AI classification error', name: 'ai.classify', error: e);
    }

    return null;
  }

  /// Resolves an image MIME type the backend allow-list accepts.
  MediaType _contentTypeForPath(String imagePath) {
    final ext = path.extension(imagePath).toLowerCase();
    switch (ext) {
      case '.png':
        return MediaType('image', 'png');
      case '.webp':
        return MediaType('image', 'webp');
      case '.heic':
        return MediaType('image', 'heic');
      case '.heif':
        return MediaType('image', 'heif');
      case '.jpg':
      case '.jpeg':
      default:
        // Camera captures and saved lot images are JPEG.
        return MediaType('image', 'jpeg');
    }
  }

  String _mapMaterialToCategoryId(String material) {
    switch (material) {
      case 'pcb':
        return 'pcb_motherboard';
      case 'cable':
        return 'copper_wire';
      case 'battery':
        return 'battery';
      case 'lcd_panel':
      case 'crt':
        return 'display_monitor';
      case 'motor':
      case 'magnet_bearing_assembly':
        return 'heavy_appliances';
      case 'mixed_plastics':
        return 'plastic';
      case 'paper':
        return 'paper';
      case 'book':
        return 'book';
      default:
        return 'mixed_ewaste';
    }
  }

  String? _mapCondition(String? suggested) {
    switch (suggested) {
      case 'good':
      case 'average':
      case 'scrap':
        return suggested;
      default:
        return null;
    }
  }

  double? _parseWeightKg(dynamic jsonResult) {
    if (jsonResult is! Map) return null;
    final estimate = jsonResult['weight_estimate'];
    if (estimate is! Map) return null;
    final value = estimate['estimated_weight_kg'] ?? estimate['value'];
    if (value is num && value > 0) {
      return value.toDouble();
    }
    return null;
  }
}
