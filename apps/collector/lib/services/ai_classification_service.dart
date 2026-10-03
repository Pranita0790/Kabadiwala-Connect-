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

  ClassificationResult({
    required this.categoryId,
    required this.categoryName,
    required this.confidenceScore,
    this.isMockResult = false,
    this.weightKg,
    this.condition,
    this.notes,
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
      notes: 'AI suggested Motherboard / PCB (92%)',
    );
  }
}
