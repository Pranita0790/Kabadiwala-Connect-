import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../core/constants/app_constants.dart';
import 'ai_classification_service.dart';
import 'backend_url.dart';
import 'lot_valuation.dart';

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

      await BackendUrl.resolve(client: _client, force: true);
      final roots = <String>{
        BackendUrl.root,
        if (baseUrl.isNotEmpty) baseUrl,
        ...BackendUrl.rootCandidates,
      };

      Object? lastError;
      for (final root in roots) {
        try {
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('$root/api/ai/analyze'),
          );
          request.files.add(
            await http.MultipartFile.fromPath(
              'file',
              imagePath,
              filename: filename,
              contentType: contentType,
            ),
          );

          final streamedResponse =
              await _client.send(request).timeout(const Duration(seconds: 30));
          final response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200) {
            BackendUrl.rememberRoot(root);
            final jsonResult = json.decode(response.body);
            final material = jsonResult['material'] as String?;
            final confidence = (jsonResult['confidence'] as num?)?.toDouble() ?? 0.0;

            if (material != null) {
              final mappedId = LotValuation.mapAiMaterialToCategoryId(
                (jsonResult['category_id'] as String?) ?? material,
              );
              final categoryLabel = jsonResult['category'] as String?;
              final electronicDevice = jsonResult['electronic_device'] as String?;
              final shortDescription = jsonResult['short_description'] as String?;
              final weightKg = _parseWeightKg(jsonResult);
              final condition = jsonResult['suggested_condition'] as String?;
              final unknown = material.toLowerCase() == 'unknown';
              final lowConfidence =
                  unknown || confidence < LotValuation.minAutoSelectConfidence;
              final notes = [
                if (electronicDevice != null && electronicDevice.trim().isNotEmpty)
                  electronicDevice.trim(),
                if (shortDescription != null && shortDescription.trim().isNotEmpty)
                  shortDescription.trim(),
              ].join('. ');
              final suggestions = <String>[];
              final rawTips = jsonResult['suggestions'];
              if (rawTips is List) {
                for (final tip in rawTips) {
                  final text = tip.toString().trim();
                  if (text.isNotEmpty) suggestions.add(text);
                }
              }
              return ClassificationResult(
                categoryId: mappedId,
                categoryName: categoryLabel ?? material,
                confidenceScore: confidence,
                isMockResult: false,
                weightKg: weightKg,
                condition: _mapCondition(condition),
                notes: notes.isEmpty ? null : notes,
                isLowConfidence: lowConfidence,
                electronicDevice: electronicDevice,
                shortDescription: shortDescription,
                suggestions: suggestions,
              );
            }
          } else {
            developer.log(
              'Failed to analyze image: ${response.statusCode}',
              name: 'ai.classify',
              error: response.body,
            );
            lastError = response.statusCode;
          }
        } catch (e) {
          lastError = e;
          developer.log('AI classify try $root failed', name: 'ai.classify', error: e);
        }
      }
      BackendUrl.lastError = lastError?.toString();
    } catch (e) {
      BackendUrl.lastError = e.toString();
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
