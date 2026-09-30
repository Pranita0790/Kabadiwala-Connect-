import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:io';

import 'package:collector/services/remote_ai_classification_service.dart';

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

    test('calls /api/ai/analyze on the Node.js backend, NOT /api/v1/analyze', () async {
      String? capturedPath;
      final mockClient = MockClient((request) async {
        capturedPath = request.url.path;
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
        baseUrl: 'http://localhost:5000',
        client: mockClient,
      );

      await service.classifyEWasteImage(dummyFile.path);

      expect(capturedPath, '/api/ai/analyze',
          reason: 'Flutter must call the Node.js backend gateway, not FastAPI directly');
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
        baseUrl: 'http://localhost:5000',
        client: mockClient,
      );

      final result = await service.classifyEWasteImage(dummyFile.path);

      expect(result, isNotNull);
      expect(result!.categoryId, 'pcb_motherboard');
      expect(result.categoryName, 'pcb');
      expect(result.confidenceScore, 0.95);
      expect(result.isMockResult, false);
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
        baseUrl: 'http://localhost:5000',
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
        baseUrl: 'http://localhost:5000',
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
        baseUrl: 'http://localhost:5000',
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
        baseUrl: 'http://localhost:5000',
        client: mockClient,
      );

      final result = await service.classifyEWasteImage(dummyFile.path);
      expect(result, isNull);
    });

    test('returns null when image file does not exist', () async {
      final service = RemoteAiClassificationService(
        baseUrl: 'http://localhost:5000',
      );

      final result = await service.classifyEWasteImage('/nonexistent/path/image.jpg');
      expect(result, isNull);
    });
  });
}
