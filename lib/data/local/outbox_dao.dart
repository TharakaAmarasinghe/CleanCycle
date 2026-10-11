import '../../core/constants.dart';
import '../../domain/models/outbox_op.dart';
import 'database.dart';

class OutboxDao {
  Future<void> enqueue(OutboxOp op) async {
    final db = await AppDatabase.instance.database;
    await db.insert('outbox', op.toMap());
  }

  /// Operations that are due to be attempted now — either never tried,
  /// or past their backoff window. Ordered oldest-first so a burst of
  /// offline activity syncs roughly in the order it happened.
  Future<List<OutboxOp>> nextBatch({int limit = SyncConfig.outboxBatchSize}) async {
    final db = await AppDatabase.instance.database;
    final nowIso = DateTime.now().toIso8601String();
    final rows = await db.query(
      'outbox',
      where: '(next_attempt_at IS NULL OR next_attempt_at <= ?) AND attempts < ?',
      whereArgs: [nowIso, SyncConfig.maxRetryAttempts],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(OutboxOp.fromMap).toList();
  }

  /// Operations that have exhausted their retry budget — shown to the
  /// user as "failed" with a manual retry action, rather than retried
  /// silently forever.
  Future<List<OutboxOp>> getFailed() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'outbox',
      where: 'attempts >= ?',
      whereArgs: [SyncConfig.maxRetryAttempts],
      orderBy: 'created_at ASC',
    );
    return rows.map(OutboxOp.fromMap).toList();
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  /// Bumps the attempt count and schedules the next try using the
  /// backoff table in SyncConfig — 2s, 4s, 8s, 16s, then capped.
  Future<void> recordFailure(String id, String error) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('outbox', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final current = OutboxOp.fromMap(rows.first);
    final nextAttempts = current.attempts + 1;
    final backoffIndex = (nextAttempts - 1).clamp(0, SyncConfig.backoffSeconds.length - 1);
    final delay = Duration(seconds: SyncConfig.backoffSeconds[backoffIndex]);

    await db.update(
      'outbox',
      {
        'attempts': nextAttempts,
        'last_error': error,
        'next_attempt_at': DateTime.now().add(delay).toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Manual retry from the Sync Centre "Retry" button — resets the
  /// attempt count so a failed op re-enters the normal queue immediately
  /// instead of waiting out its last backoff window.
  Future<void> resetForRetry(String id) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'outbox',
      {'attempts': 0, 'next_attempt_at': null, 'last_error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> pendingCount() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM outbox WHERE attempts < ?',
      [SyncConfig.maxRetryAttempts],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// Every operation still waiting (retry budget not exhausted), whether
  /// or not it is currently due. Used by the Sync Centre list.
  Future<List<OutboxOp>> getPending() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'outbox',
      where: 'attempts < ?',
      whereArgs: [SyncConfig.maxRetryAttempts],
      orderBy: 'created_at ASC',
    );
    return rows.map(OutboxOp.fromMap).toList();
  }

  /// Makes every waiting operation due immediately, keeping its attempt
  /// count. This is what a manual "Sync now" needs: without it, an op
  /// inside its backoff window would be skipped.
  Future<void> clearBackoff() async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'outbox',
      {'next_attempt_at': null},
      where: 'attempts < ?',
      whereArgs: [SyncConfig.maxRetryAttempts],
    );
  }

  /// Gives every exhausted operation a fresh retry budget. This is what
  /// the Retry action must do; re-running the sync alone skips them.
  Future<void> resetAllFailed() async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'outbox',
      {'attempts': 0, 'next_attempt_at': null, 'last_error': null},
      where: 'attempts >= ?',
      whereArgs: [SyncConfig.maxRetryAttempts],
    );
  }
}