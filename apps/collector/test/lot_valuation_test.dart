import 'package:flutter_test/flutter_test.dart';
import 'package:kabadiwala_connect/repositories/price_repository.dart';
import 'package:kabadiwala_connect/services/ai_classification_service.dart';
import 'package:kabadiwala_connect/services/lot_valuation.dart';

void main() {
  group('LotValuation', () {
    test('maps FastAPI classes onto existing lot category ids', () {
      expect(LotValuation.mapAiMaterialToCategoryId('pcb'), 'pcb_motherboard');
      expect(LotValuation.mapAiMaterialToCategoryId('cable'), 'copper_wire');
      expect(LotValuation.mapAiMaterialToCategoryId('battery'), 'battery');
      expect(LotValuation.mapAiMaterialToCategoryId('lcd_panel'), 'display_monitor');
      expect(LotValuation.mapAiMaterialToCategoryId('pcb_motherboard'), 'pcb_motherboard');
      expect(LotValuation.mapAiMaterialToCategoryId('unknown'), 'mixed_ewaste');
    });

    test('parses recycler website GET /api/rates payload onto lot categories', () {
      final prices = LotValuation.pricesFromRatesResponse({
        'success': true,
        'data': {
          'rates': [
            {
              'id': 'pcb',
              'material': 'pcb',
              'materialId': 'pcb',
              'displayName': 'PCB / Motherboard',
              'category': 'E-Waste',
              'ratePerKg': 448,
              'unit': 'INR/kg',
              'region': 'IN-MH',
              'source': 'SEED',
              'updatedAt': '2026-10-03T00:00:00.000Z',
            },
            {
              'id': 'mixed_plastics',
              'material': 'mixed_plastics',
              'materialId': 'mixed_plastics',
              'displayName': 'Mixed Plastics',
              'ratePerKg': 45,
              'unit': 'INR/kg',
              'region': 'IN-MH',
            },
          ],
          'count': 2,
        },
        'rates': [],
      });

      expect(prices, hasLength(2));
      final pcb = prices.firstWhere((p) => p.categoryId == 'pcb_motherboard');
      expect(pcb.material, 'PCB / Motherboard');
      expect(pcb.unit, 'kg');
      expect(pcb.minPrice, closeTo(448 * 0.92, 0.01));
      expect(pcb.maxPrice, closeTo(448 * 1.08, 0.01));

      final bookRange = LotValuation.ratesPerKg('book', prices);
      expect(bookRange.$1, closeTo(45 * 0.92, 0.01));
    });

    test('does not auto-select unknown or low-confidence results', () {
      final low = ClassificationResult(
        categoryId: 'pcb_motherboard',
        categoryName: 'pcb',
        confidenceScore: 0.42,
        isLowConfidence: true,
      );
      final unknown = ClassificationResult(
        categoryId: 'mixed_ewaste',
        categoryName: 'unknown',
        confidenceScore: 0.91,
      );
      final ok = ClassificationResult(
        categoryId: 'battery',
        categoryName: 'battery',
        confidenceScore: 0.81,
      );
      expect(LotValuation.shouldAutoSelect(low), isFalse);
      expect(LotValuation.shouldAutoSelect(unknown), isFalse);
      expect(LotValuation.shouldAutoSelect(ok), isTrue);
    });

    test('estimates ₹ range from rate card, weight, and condition', () {
      final prices = PriceRepository.defaultPrices();
      final good = LotValuation.estimateRange(
        categoryId: 'pcb_motherboard',
        weightKg: 2,
        condition: 'good',
        prices: prices,
      );
      final scrap = LotValuation.estimateRange(
        categoryId: 'pcb_motherboard',
        weightKg: 2,
        condition: 'scrap',
        prices: prices,
      );
      expect(good.$1, closeTo(480, 0.1));
      expect(good.$2, closeTo(580, 0.1));
      expect(scrap.$1, lessThan(good.$1));
      expect(scrap.$2, lessThan(good.$2));
    });
  });
}
