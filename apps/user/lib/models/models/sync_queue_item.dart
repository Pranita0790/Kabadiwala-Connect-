class SyncQueueItem {
  final String id;
  final String entityType;
  final String entityId;
  final String operation; // 'CREATE', 'UPDATE', 'DELETE'
  final DateTime createdAt;
  final int retryCount;

  SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
    };
  }

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      operation: map['operation'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
    );
  }

  SyncQueueItem copyWith({
    String? id,
    String? entityType,
    String? entityId,
    String? operation,
    DateTime? createdAt,
    int? retryCount,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
