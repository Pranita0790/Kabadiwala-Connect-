import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
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
    // Node.js backend host (production by default). Override with
    // --dart-define=BACKEND_URL=http://10.0.2.2:PORT for a local server.
    this.baseUrl = AppConstants.apiHost,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<ClassificationResult?> classifyEWasteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        print('Image file does not exist: $imagePath');
        return null;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/ai/analyze'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imagePath,
          filename: path.basename(imagePath),
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
          
          return ClassificationResult(
            categoryId: categoryId,
            categoryName: material,
            confidenceScore: confidence,
            isMockResult: false,
          );
        }
      } else {
        print('Failed to analyze image: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Error during AI classification: $e');
    }
    
    return null;
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
      default:
        return 'mixed_ewaste';
    }
  }
}
