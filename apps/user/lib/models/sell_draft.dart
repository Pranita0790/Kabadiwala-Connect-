import 'material_item.dart';
import 'vendor.dart';

enum SellFulfillmentMode {
  pickup, // Kabadiwala comes home
  shopVisit, // User goes to shop / direct cash
}

class SellLineItem {
  final MaterialItem material;
  final double weightKg;

  const SellLineItem({
    required this.material,
    required this.weightKg,
  });

  double rateFor(Vendor vendor) =>
      vendor.ratesPerKg[material.category] ??
      (vendor.ratesPerKg.values.isNotEmpty ? vendor.ratesPerKg.values.first : 0);

  double amountFor(Vendor vendor) => rateFor(vendor) * weightKg;
}

/// In-progress sell journey after kabadiwala is chosen.
class SellDraft {
  final Vendor vendor;
  final List<SellLineItem> lines;
  final SellFulfillmentMode? mode;
  final String? pickupAddress;
  final String? preferredTime;
  final String? note;

  const SellDraft({
    required this.vendor,
    this.lines = const [],
    this.mode,
    this.pickupAddress,
    this.preferredTime,
    this.note,
  });

  double get totalWeightKg =>
      lines.fold(0.0, (sum, line) => sum + line.weightKg);

  double get estimatedAmount =>
      lines.fold(0.0, (sum, line) => sum + line.amountFor(vendor));

  String get materialsSummary =>
      lines.map((l) => '${l.material.category} (${l.weightKg.toStringAsFixed(1)} kg)').join(', ');

  String get primaryCategory =>
      lines.isNotEmpty ? lines.first.material.category : 'Other';

  String get primaryMaterialName =>
      lines.length == 1
          ? lines.first.material.name
          : 'Mixed scrap (${lines.length} types)';

  SellDraft copyWith({
    Vendor? vendor,
    List<SellLineItem>? lines,
    SellFulfillmentMode? mode,
    String? pickupAddress,
    String? preferredTime,
    String? note,
  }) {
    return SellDraft(
      vendor: vendor ?? this.vendor,
      lines: lines ?? this.lines,
      mode: mode ?? this.mode,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      preferredTime: preferredTime ?? this.preferredTime,
      note: note ?? this.note,
    );
  }
}
