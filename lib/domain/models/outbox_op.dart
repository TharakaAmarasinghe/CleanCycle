/// One row per pending write. Every repository write (create a bag,
/// submit a report, log a custody event) inserts locally AND enqueues
/// one of these, inside the same database transaction — so a killed
/// app between the two steps can never leave an orphaned record.
class OutboxOp {
  final String id;
  final String opType; // 'CREATE_BAG' | 'SUBMIT_REPORT' | 'ADD_CUSTODY'
  final String payloadJson; // JSON-encoded snapshot of the record
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  final DateTime? nextAttemptAt;

  OutboxOp({
    required this.id,
    required this.opType,
    required this.payloadJson,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
    this.nextAttemptAt,
  });

  factory OutboxOp.fromMap(Map<String, dynamic> map) {
    return OutboxOp(
      id: map['id'] as String,
      opType: map['op_type'] as String,
      payloadJson: map['payload'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      attempts: map['attempts'] as int,
      lastError: map['last_error'] as String?,
      nextAttemptAt: map['next_attempt_at'] != null
          ? DateTime.parse(map['next_attempt_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'op_type': opType,
        'payload': payloadJson,
        'created_at': createdAt.toIso8601String(),
        'attempts': attempts,
        'last_error': lastError,
        'next_attempt_at': nextAttemptAt?.toIso8601String(),
      };
}