import 'dart:async';

/// Classification result returned by AI interface
class ClassificationResult {
  final String categoryId;
  final String categoryName;
  final double confidenceScore;
  final bool isMockResult;

  ClassificationResult({
    required this.categoryId,
    required this.categoryName,
    required this.confidenceScore,
    this.isMockResult = false,
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
    // Simulate network API round-trip delay for image analysis
    await Future.delayed(const Duration(milliseconds: 1200));

    // Return mock AI suggestion
    return ClassificationResult(
      categoryId: 'pcb_motherboard',
      categoryName: 'Motherboard / PCB',
      confidenceScore: 0.92,
      isMockResult: true, // Clearly marked as mock data
    );
  }
}
