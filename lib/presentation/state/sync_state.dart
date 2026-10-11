import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../data/local/outbox_dao.dart';
import '../../domain/services/connectivity_service.dart';
import '../../domain/services/sync_service.dart';

/// Tracks connectivity + sync progress for the UI. Sync is triggered on
/// app start, on reconnect, after a local write, on pull-to-refresh and
/// manually. It is never polled while idle: the only timer is a one-shot
/// retry that exists solely while queued work remains, and it stops once
/// the queue is empty or every item has exhausted its retries.
class SyncState extends ChangeNotifier {
  final SyncService _syncService = SyncService();
  final ConnectivityService _connectivity = ConnectivityService();
  final OutboxDao _outboxDao = OutboxDao();

  bool isOnline = true;
  bool isSyncing = false;
  int pendingCount = 0;
  int failedCount = 0;
  DateTime? lastSyncAt;

  StreamSubscription<bool>? _sub;
  Timer? _retryTimer;

  SyncState() {
    _init();
  }

  Future<void> _init() async {
    isOnline = await _connectivity.isCurrentlyOnline();
    notifyListeners();
    _sub = _connectivity.onlineStatusStream.listen(_onConnectivityChanged);
    await triggerSync();
  }

  Future<void> _onConnectivityChanged(bool online) async {
    final justCameOnline = online && !isOnline;
    isOnline = online;
    notifyListeners();
    if (justCameOnline) {
      await triggerSync();
    } else if (!online) {
      _retryTimer?.cancel();
      await refreshCounts();
    }
  }

  /// Called on app start, on reconnect, after creating something, on
  /// pull-to-refresh, and by the manual actions.
  Future<void> triggerSync() async {
    if (isSyncing) return;

    // Recount first: the outbox may just have gained a row (a bag created
    // offline) and the banner and Sync Centre must show it immediately.
    await refreshCounts();
    if (!isOnline) return; // nothing to attempt; it waits for reconnect

    isSyncing = true;
    notifyListeners();
    try {
      await _syncService.run();
    } finally {
      isSyncing = false;
      await _readCounts();
      if (pendingCount == 0 && failedCount == 0) lastSyncAt = DateTime.now();
      notifyListeners();
      _scheduleRetryIfNeeded();
    }
  }

  /// Backoff made real: a failed push records when it may next be tried,
  /// and this wakes the sync up once to try again. It re-arms only while
  /// there is still work queued, and each item gets at most
  /// SyncConfig.maxRetryAttempts tries, so it always terminates.
  void _scheduleRetryIfNeeded() {
    _retryTimer?.cancel();
    if (isOnline && pendingCount > 0) {
      _retryTimer = Timer(const Duration(seconds: 5), triggerSync);
    }
  }

  /// Manual "Sync now": operations waiting out a backoff window are
  /// retried immediately instead of waiting for the next trigger.
  Future<void> syncNow() async {
    await _outboxDao.clearBackoff();
    await triggerSync();
  }

  /// Manual "Retry" for operations that used up their automatic
  /// attempts: fresh budget, then sync.
  Future<void> retryFailed() async {
    await _outboxDao.resetAllFailed();
    await syncNow();
  }

  Future<void> _readCounts() async {
    pendingCount = await _outboxDao.pendingCount();
    failedCount = (await _outboxDao.getFailed()).length;
  }

  Future<void> refreshCounts() async {
    await _readCounts();
    notifyListeners();
  }

  /// Pull side: merge custody events other devices wrote for these bags
  /// into local SQLite. Skipped when offline and never throws; a failed
  /// pull just means the screen keeps showing what's on this device.
  Future<void> pullCustodyEvents(List<String> bagIds) async {
    if (!isOnline || bagIds.isEmpty) return;
    try {
      await _syncService.pullCustodyEvents(bagIds);
    } catch (e) {
      debugPrint('SyncState: custody pull failed: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}