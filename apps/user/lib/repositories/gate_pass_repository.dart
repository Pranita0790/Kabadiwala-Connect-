import 'package:flutter/foundation.dart';
import '../models/gate_pass.dart';

class GatePassRepository extends ChangeNotifier {
  static final GatePassRepository _instance = GatePassRepository._internal();
  factory GatePassRepository() => _instance;
  GatePassRepository._internal() {
    _initDefault();
  }

  final List<GatePass> _passes = [];

  void _initDefault() {
    _passes.add(
      GatePass(
        passId: 'PASS-2026-8891',
        pinCode: '4892',
        collectorName: 'Ramesh Kumar (Green Recyclers)',
        collectorPhone: '+91 98765 43210',
        vehicleNumber: 'MH-12-AB-3456',
        residentName: 'Ananya Sharma',
        residentPhone: '+91 98765 43210',
        societyAddress: 'Flat B-402, Green Acres Housing Society, Andheri East',
        entryDate: 'Today, Oct 4, 2026',
        timeWindow: '04:00 PM - 05:00 PM',
        status: 'ACTIVE',
      ),
    );
  }

  List<GatePass> get passes => List.unmodifiable(_passes);

  GatePass? get activePass => _passes.firstWhere((p) => p.status == 'ACTIVE', orElse: () => _passes.first);

  GatePass createPass({
    required String collectorName,
    required String collectorPhone,
    required String vehicleNumber,
    required String residentName,
    required String residentPhone,
    required String societyAddress,
    required String entryDate,
    required String timeWindow,
  }) {
    final newPass = GatePass(
      passId: 'PASS-2026-${1000 + _passes.length + 1}',
      pinCode: '${1000 + (_passes.length * 123) % 8999}',
      collectorName: collectorName,
      collectorPhone: collectorPhone,
      vehicleNumber: vehicleNumber,
      residentName: residentName,
      residentPhone: residentPhone,
      societyAddress: societyAddress,
      entryDate: entryDate,
      timeWindow: timeWindow,
      status: 'ACTIVE',
    );

    _passes.insert(0, newPass);
    notifyListeners();
    return newPass;
  }
}
