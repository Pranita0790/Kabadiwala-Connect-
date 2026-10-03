import 'package:flutter_test/flutter_test.dart';
import 'package:kabadiwala_connect/models/e_waste_lot.dart';
import 'package:kabadiwala_connect/services/api_service.dart';

void main() {
  final api = RemoteApiService(baseUrl: 'http://10.0.2.2:5000/api');

  test('lot payload omits null notes/imagePath so Zod optional fields pass', () {
    final lot = EWasteLot(
      id: '11111111-1111-4111-8111-111111111111',
      categoryId: 'battery',
      categoryName: 'Batteries',
      weightKg: 10,
      condition: 'scrap',
      estimatedMinPrice: 630,
      estimatedMaxPrice: 770,
      status: 'CREATED',
      syncStatus: 'PENDING_SYNC',
      createdAt: DateTime(2026, 10, 3),
    );

    final body = api.lotToApiBody(lot);
    expect(body.containsKey('notes'), isFalse);
    expect(body.containsKey('imagePath'), isFalse);
    expect(body['materialId'], 'battery');
    expect(body['condition'], 'Scrap');
    expect(body['clientReference'], lot.id);
  });

  test('maps collector categories onto seeded material ids', () {
    expect(RemoteApiService.mapMaterialId('display_monitor'), 'lcd_panel');
    expect(RemoteApiService.mapMaterialId('mixed_ewaste'), 'mixed_plastics');
    expect(RemoteApiService.mapMaterialId('pcb_motherboard'), 'pcb');
    expect(RemoteApiService.mapCondition('average'), 'Partial');
  });
}
