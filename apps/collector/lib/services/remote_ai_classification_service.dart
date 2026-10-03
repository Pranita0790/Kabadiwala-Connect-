import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'ai_classification_service.dart';

/// Calls the Node.js backend AI gateway for e-waste classification.
/// Architecture: Flutter → Node.js Backend → FastAPI AI Service → MobileNetV3
/// Flutter never calls the Python AI service directly.
class RemoteAiClassificationService implements AiClassificationService {
  final String baseUrl;
  final http.Client _client;
  
  RemoteAiClassificationService({
    this.baseUrl = 'http://10.0.2.2:5000', // Node.js backend (Android emulator loopback)
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<ClassificationResult?> classifyEWasteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        developer.log('Image file does not exist: $imagePath', name: 'ai.classify');
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
