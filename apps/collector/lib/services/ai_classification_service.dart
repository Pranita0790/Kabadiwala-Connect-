import 'dart:async';

/// Classification result returned by AI interface
class ClassificationResult {
  final String categoryId;
  final String categoryName;
  final double confidenceScore;
  final bool isMockResult;
  final double? weightKg;
  final String? condition;
  final String? notes;
  final bool isLowConfidence;
  final String? electronicDevice;
  final String? shortDescription;
  final List<String> suggestions;

  ClassificationResult({
    required this.categoryId,
    required this.categoryName,
    required this.confidenceScore,
    this.isMockResult = false,
    this.weightKg,
    this.condition,
    this.notes,
    this.isLowConfidence = false,
    this.electronicDevice,
    this.shortDescription,
    this.suggestions = const [],
  });
}

/// Abstract interface for remote AI e-waste classification service.
/// Flutter consumes AI responses through this interface abstraction;
/// no ML model training or execution takes place inside Flutter.
abstract class AiClassificationService {
  Future<ClassificationResult?> classifyEWasteImage(String imagePath);
}

/// Mock AI classification service implementation.
/// Clearly marked as MOCK DATA until the remote classification API is connected.
class MockAiClassificationService implements AiClassificationService {
  @override
  Future<ClassificationResult?> classifyEWasteImage(String imagePath) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    return ClassificationResult(
      categoryId: 'pcb_motherboard',
      categoryName: 'Motherboard / PCB',
      confidenceScore: 0.92,
      isMockResult: true,
      weightKg: 1.5,
      condition: 'scrap',
      electronicDevice: 'Printed circuit board',
      shortDescription:
          'Circuit board with chips and copper traces; best match is Motherboard / PCB.',
      notes:
          'Printed circuit board. Circuit board with chips and copper traces; best match is Motherboard / PCB.',
      suggestions: const [
        'This looks like a circuit board / converter module.',
        'Save as Motherboard / PCB for a better rate.',
      ],
    );
  }
}
