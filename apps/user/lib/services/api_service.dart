import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/vendor.dart';
import '../models/sell_request.dart';
import '../models/payment_record.dart';
import '../models/collection_record.dart';

class ApiService {
  static const List<String> apiBaseUrls = [
    'http://127.0.0.1:5000/api', // iOS Simulator / Localhost
    'http://localhost:5000/api', // Local Dev
    'http://10.0.2.2:5000/api',   // Android Emulator
    'https://kabadiwala-backend-69wr.onrender.com/api', // Production Cloud
  ];

  // Fetch Vendors with automatic multi-URL fallback
  static Future<List<Vendor>> fetchNearbyVendors() async {
    for (final url in apiBaseUrls) {
      try {
        final response = await http.get(Uri.parse('$url/user/vendors')).timeout(
          const Duration(seconds: 2),
        );
        if (response.statusCode == 200) {
          final body = json.decode(response.body);
          final list = body['data']['vendors'] as List;
          return list.map((jsonItem) => Vendor.fromJson(jsonItem as Map<String, dynamic>)).toList();
        }
      } catch (_) {
        // Try next URL
      }
    }
    return [];
  }

  // Create Pickup Request via POST /user/requests
  static Future<SellRequest?> createPickupRequest({
    required String userName,
    required String userPhone,
    required String pickupAddress,
    required String materialCategory,
    required String materialName,
    required double estimatedWeightKg,
    required double ratePerKg,
    required String preferredTimeSlot,
    required String description,
    required String vendorId,
  }) async {
    final payload = json.encode({
      'userName': userName,
      'userPhone': userPhone,
      'pickupAddress': pickupAddress,
      'materialCategory': materialCategory,
      'materialName': materialName,
      'estimatedWeightKg': estimatedWeightKg,
      'ratePerKg': ratePerKg,
      'preferredTimeSlot': preferredTimeSlot,
      'description': description,
      'collectorId': vendorId,
    });

    for (final url in apiBaseUrls) {
      try {
        final response = await http.post(
          Uri.parse('$url/user/requests'),
          headers: {'Content-Type': 'application/json'},
          body: payload,
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 201 || response.statusCode == 200) {
          final body = json.decode(response.body);
          final data = body['data']['request'];
          return SellRequest(
            id: data['id'],
            materialName: data['materialName'],
            materialCategory: data['materialCategory'],
            ratePerKg: (data['ratePerKg'] as num).toDouble(),
            userName: data['userName'],
            userPhone: data['userPhone'],
            pickupAddress: data['pickupAddress'],
            preferredTimeSlot: data['preferredTimeSlot'],
            estimatedWeightKg: (data['estimatedWeightKg'] as num).toDouble(),
            description: data['description'],
            status: SellRequestStatus.created,
            paymentStatus: 'PENDING',
            createdAt: DateTime.now(),
          );
        }
      } catch (_) {
        // Try next URL
      }
    }
    return null;
  }
}
