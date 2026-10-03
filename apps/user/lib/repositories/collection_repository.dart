import 'package:flutter/foundation.dart';
import '../models/collection_record.dart';

class CollectionRepository extends ChangeNotifier {
  static final CollectionRepository _instance = CollectionRepository._internal();
  factory CollectionRepository() => _instance;
  CollectionRepository._internal();

  final List<CollectionRecord> _collections = List.from(CollectionRecord.sampleCollections);

  List<CollectionRecord> get collections => List.unmodifiable(_collections);

  double get totalWeightKg => _collections.fold(0.0, (sum, c) => sum + c.totalWeightKg);
  double get totalIncome => _collections.fold(0.0, (sum, c) => sum + c.totalAmount);

  static List<CollectionRecord> getSampleCollections() {
    return _instance.collections;
  }

  void addCollection(CollectionRecord record) {
    _collections.insert(0, record);
    notifyListeners();
  }
}
