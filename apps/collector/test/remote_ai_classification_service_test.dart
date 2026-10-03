import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:io';

import 'package:kabadiwala_connect/services/ai_classification_service.dart';
import 'package:kabadiwala_connect/services/remote_ai_classification_service.dart';

/// Captures the multipart file Content-Type before MockClient finalizes the body.
class _CapturingClient extends http.BaseClient {
  _CapturingClient(this._inner);

  final http.Client _inner;
  String? path;
  MediaType? fileContentType;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    path = request.url.path;
    if (request is http.MultipartRequest && request.files.isNotEmpty) {
      fileContentType = request.files.first.contentType;
    }
    return _inner.send(request);
  }
}

void main() {
  group('RemoteAiClassificationService (via Node.js backend gateway)', () {
    late File dummyFile;

    setUp(() async {
      dummyFile = File('test_dummy_image.jpg');
      await dummyFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG magic bytes
    });

    tearDown(() async {
      if (await dummyFile.exists()) {
        await dummyFile.delete();
      }
    });

    test('calls /api/ai/analyze on the Node.js backend with image MIME type', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'material': 'pcb',
            'confidence': 0.95,
            'critical_mineral': true,
            'critical_mineral_reason': null,
            'model_version': '1.0',
            'rule_version': '1.0',
            'supported_materials': ['pcb'],
            'weight_estimate': {'value': 1.0, 'unit': 'kg'},
            'value_estimate': {'min': 100, 'max': 200, 'currency': 'INR'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final capturing = _CapturingClient(mockClient);

      final service = RemoteAiClassificationService(
        baseUrl: 'http://localhost:5001',
        client: capturing,
      );

      await service.classifyEWasteImage(dummyFile.path);

      expect(capturing.path, '/api/ai/analyze',
          reason: 'Flutter must call the Node.js backend gateway, not FastAPI directly');
      expect(capturing.fileContentType?.mimeType, 'image/jpeg',
          reason: 'Backend rejects application/octet-stream; JPEG content-type is required');
    });

    test('returns ClassificationResult on successful classification', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'material': 'pcb',
            'confidence': 0.95,
            'critical_mineral': true,
            'critical_mineral_reason': null,
            'model_version': '1.0',
            'rule_version': '1.0',
            'supported_materials': ['pcb'],
            'weight_estimate': {'value': 1.0, 'unit': 'kg'},
            'value_estimate': {'min': 100, 'max': 200, 'currency': 'INR'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = RemoteAiClassificationService(
        baseUrl: 'http://localhost:5001',
        client: mockClient,
      );

      final result = await service.classifyEWasteImage(dummyFile.path);

      expect(result, isNotNull);
      expect(result!.categoryId, 'pcb_motherboard');
      expect(result.categoryName, 'pcb');
      expect(result.confidenceScore, 0.95);
      expect(result.isMockResult, false);
      expect(result.weightKg, 1.0);
    });

    test('maps paper, book and plastic materials onto collector categories', () async {
      Future<ClassificationResult?> classify(String material) async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'material': material,
              'confidence': 0.8,
              'critical_mineral': false,
              'critical_mineral_reason': null,
              'model_version': '1.0',
              'rule_version': '1.0',
              'supported_materials': [material],
              'weight_estimate': {'estimated_weight_kg': 2.0},
              'suggested_condition': 'average',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final service = RemoteAiClassificationService(
          baseUrl: 'http://localhost:5001',
          client: mockClient,
        );
        return service.classifyEWasteImage(dummyFile.path);
      }

      final paper = await classify('paper');
      expect(paper?.categoryId, 'paper');
      expect(paper?.weightKg, 2.0);
      expect(paper?.condition, 'average');

      final book = await classify('book');
      expect(book?.categoryId, 'book');

      final plastic = await classify('mixed_plastics');
      expect(plastic?.categoryId, 'plastic');
    });

    test('maps battery material correctly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'material': 'battery',
            'confidence': 0.88,
            'critical_mineral': true,
            'critical_mineral_reason': 'Lithium detected',
            'model_version': '1.0',
            'rule_version': '1.0',
            'supported_materials': ['battery'],
            'weight_estimate': {'value': 0.5, 'unit': 'kg'},
            'value_estimate': {'min': 50, 'max': 80, 'currency': 'INR'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = RemoteAiClassificationService(
        baseUrl: 'http://localhost:5001',
        client: mockClient,
      );

      final result = await service.classifyEWasteImage(dummyFile.path);

      expect(result, isNotNull);
      expect(result!.categoryId, 'battery');
      expect(result.confidenceScore, 0.88);
    });

    test('returns null on non-200 backend response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "Invalid image"}', 400);
      });

      final service = RemoteAiClassificationService(
        baseUrl: 'http://localhost:5001',
        client: mockClient,
      );

      final result = await service.classifyEWasteImage(dummyFile.path);
      expect(result, isNull);
    });

    test('returns null when network exception occurs', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final service = RemoteAiClassificationService(
        baseUrl: 'http://localhost:5001',
        client: mockClient,
      );

      final result = await service.classifyEWasteImage(dummyFile.path);
      expect(result, isNull);
    });

    test('returns null when backend returns malformed JSON', () async {
      final mockClient = MockClient((request) async {
        return http.Response('this is not json', 200);
      });

      final service = RemoteAiClassificationService(
        baseUrl: 'http://localhost:5001',
        client: mockClient,
      );

      final result = await service.classifyEWasteImage(dummyFile.path);
      expect(result, isNull);
    });

    test('returns null when image file does not exist', () async {
      final service = RemoteAiClassificationService(
        baseUrl: 'http://localhost:5001',
      );

      final result = await service.classifyEWasteImage('/nonexistent/path/image.jpg');
      expect(result, isNull);
    });
  });
}
