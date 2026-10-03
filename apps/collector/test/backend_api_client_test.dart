import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kabadiwala_connect/models/e_waste_lot.dart';
import 'package:kabadiwala_connect/services/api_service.dart';
import 'package:kabadiwala_connect/services/backend_api_client.dart';
import 'package:kabadiwala_connect/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late DatabaseService dbService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kc_backend_test_');
    DatabaseService.setTestFactory(
      databaseFactoryFfi,
      customPath: '${tempDir.path}/test.db',
    );
    dbService = DatabaseService.instance;
    await dbService.database;
  });

  tearDown(() async {
    BackendApiClient.setRemoteEnabledForTesting(null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  BackendApiClient clientWith(http.Client mockClient) {
    BackendApiClient.setRemoteEnabledForTesting(true);
    return BackendApiClient(
      baseUrl: 'http://test.local/api',
      dbService: dbService,
      client: mockClient,
    );
  }

  http.Response jsonBody(Map<String, dynamic> body, int status) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );

  EWasteLot sampleLot() => EWasteLot(
        id: '11111111-1111-4111-8111-111111111111',
        categoryId: 'pcb_motherboard',
        categoryName: 'PCB / Motherboard',
        weightKg: 2.5,
        condition: 'good',
        estimatedMinPrice: 0,
        estimatedMaxPrice: 0,
        status: 'CREATED',
        syncStatus: 'PENDING_SYNC',
        createdAt: DateTime.now(),
      );

  test('fetchMarketPrices maps the backend rates envelope', () async {
    final client = clientWith(MockClient((request) async {
      expect(request.url.path, '/api/prices');
      return jsonBody({
        'success': true,
        'rates': [
          {
            'id': 'pcb',
            'materialId': 'pcb',
            'displayName': 'PCB / Motherboard',
            'ratePerKg': 448,
            'unit': 'kg',
            'region': 'IN-MH',
            'source': 'MANUAL',
            'updatedAt': '2026-09-17T00:00:00.000Z',
          },
        ],
        'count': 1,
      }, 200);
    }));

    final response = await RemoteApiService(client: client).fetchMarketPrices();

    expect(response.success, isTrue);
    expect(response.data, hasLength(1));
    expect(response.data!.single.categoryId, 'pcb');
    expect(response.data!.single.minPrice, 448);
  });

  test('fetchMarketPrices falls back to the legacy /rates array', () async {
    final client = clientWith(MockClient((request) async {
      if (request.url.path == '/api/prices') {
        return jsonBody({'success': false, 'message': 'Route not found'}, 404);
      }
      expect(request.url.path, '/api/rates');
      return http.Response(
        jsonEncode([
          {'id': 'pcb', 'material': 'PCB', 'ratePerKg': 448, 'unit': '₹/kg'},
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }));

    final response = await RemoteApiService(client: client).fetchMarketPrices();

    expect(response.success, isTrue);
    expect(response.data!.single.categoryId, 'pcb');
    expect(response.data!.single.minPrice, 448);
  });

  test('uploadLot posts the clientReference and mapped material id', () async {
    Map<String, dynamic>? captured;
    final client = clientWith(MockClient((request) async {
      expect(request.url.path, '/api/lots');
      expect(request.method, 'POST');
      captured = jsonDecode(request.body) as Map<String, dynamic>;
      return jsonBody(
        {'success': true, 'lot': {'id': 'pcb'}, 'created': true},
        201,
      );
    }));

    final response =
        await RemoteApiService(client: client).uploadLot(sampleLot());

    expect(response.success, isTrue);
    expect(captured!['clientReference'], sampleLot().id);
    expect(captured!['materialId'], 'pcb');
    expect(captured!['condition'], 'Good');
    expect(captured!['syncStatus'], 'SYNCED');
  });

  test('uploadLot surfaces a network failure instead of mock success', () async {
    final client = clientWith(MockClient((request) async {
      throw const SocketException('no route to host');
    }));

    final response =
        await RemoteApiService(client: client).uploadLot(sampleLot());

    expect(response.success, isFalse);
    expect(response.statusCode, 0);
  });
}
