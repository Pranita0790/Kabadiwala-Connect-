/// Optional photo + Gemini suggestion passed from Camera into Create Lot.
/// Create Lot never classifies; it only applies these fields if present.
class CreateLotArgs {
  final String? imagePath;
  final String? categoryId;
  final double? weightKg;
  final String? condition;
  final String? notes;
  final String? electronicDevice;
  final String? shortDescription;

  const CreateLotArgs({
    this.imagePath,
    this.categoryId,
    this.weightKg,
    this.condition,
    this.notes,
    this.electronicDevice,
    this.shortDescription,
  });
}
