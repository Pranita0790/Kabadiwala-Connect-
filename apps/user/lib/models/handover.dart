import 'dart:convert';
import '../core/constants/app_constants.dart';

/// Model representing an offline-first e-waste material handover record.
/// Encapsulates a secure, non-sensitive QR payload for collector-recycler physical transactions.
class Handover {
  final String id;
  final String lotId;
  final String recyclerId;
  final String recyclerName;
  final String materialCategory;
  final double weightKg;
  final double agreedAmount;
  final String status;
  final String qrPayload;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final String syncStatus;
  final int retryCount;

  const Handover({
    required this.id,
    required this.lotId,
    required this.recyclerId,
    required this.recyclerName,
    required this.materialCategory,
    required this.weightKg,
    required this.agreedAmount,
    this.status = AppConstants.handoverPending,
    required this.qrPayload,
    required this.createdAt,
    this.confirmedAt,
    this.syncStatus = AppConstants.syncPending,
    this.retryCount = 0,
  });

  double get agreedPrice => agreedAmount;

  /// Generates a safe, non-personal conceptual QR payload string
  static String buildSafeQrPayload({
    required String handoverId,
    required String lotId,
    int version = 1,
  }) {
    return jsonEncode({
      'handover_id': handoverId,
      'lot_id': lotId,
      'version': version,
      'type': 'E_WASTE_HANDOVER',
    });
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lot_id': lotId,
      'recycler_id': recyclerId,
      'recycler_name': recyclerName,
      'material_category': materialCategory,
      'weight_kg': weightKg,
      'agreed_amount': agreedAmount,
      'status': status,
      'qr_payload': qrPayload,
      'created_at': createdAt.toIso8601String(),
      'confirmed_at': confirmedAt?.toIso8601String(),
      'sync_status': syncStatus,
      'retry_count': retryCount,
    };
  }

  factory Handover.fromMap(Map<String, dynamic> map) {
    return Handover(
      id: map['id'] as String,
      lotId: map['lot_id'] as String,
      recyclerId: map['recycler_id'] as String,
      recyclerName: map['recycler_name'] as String? ?? 'Recycler',
      materialCategory: map['material_category'] as String? ?? 'E-Waste',
      weightKg: (map['weight_kg'] as num?)?.toDouble() ?? 0.0,
      agreedAmount: (map['agreed_amount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? AppConstants.handoverPending,
      qrPayload: map['qr_payload'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      confirmedAt: map['confirmed_at'] != null
          ? DateTime.parse(map['confirmed_at'] as String)
          : null,
      syncStatus: map['sync_status'] as String? ?? AppConstants.syncPending,
      retryCount: (map['retry_count'] as int?) ?? 0,
    );
  }

  Handover copyWith({
    String? id,
    String? lotId,
    String? recyclerId,
    String? recyclerName,
    String? materialCategory,
    double? weightKg,
    double? agreedAmount,
    String? status,
    String? qrPayload,
    DateTime? createdAt,
    DateTime? confirmedAt,
    String? syncStatus,
    int? retryCount,
  }) {
    return Handover(
      id: id ?? this.id,
      lotId: lotId ?? this.lotId,
      recyclerId: recyclerId ?? this.recyclerId,
      recyclerName: recyclerName ?? this.recyclerName,
      materialCategory: materialCategory ?? this.materialCategory,
      weightKg: weightKg ?? this.weightKg,
      agreedAmount: agreedAmount ?? this.agreedAmount,
      status: status ?? this.status,
      qrPayload: qrPayload ?? this.qrPayload,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
