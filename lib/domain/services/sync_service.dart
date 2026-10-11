import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../data/local/bag_dao.dart';
import '../../data/local/custody_dao.dart';
import '../../data/local/outbox_dao.dart';
import '../../data/remote/firestore_bag_api.dart';
import '../models/custody_event.dart';

/// The heart of the offline layer. Call run() whenever a push should be
/// attempted, pullCustodyEvents() when a screen wants other devices'
/// events. Nothing here schedules itself on a timer.
class SyncService {
  final OutboxDao _outboxDao;
  final BagDao _bagDao;
  final CustodyDao _custodyDao;
  final FirestoreBagApi _api;

  bool _running = false; // re-entrancy guard — never two pushes at once

  SyncService({
    OutboxDao? outboxDao,
    BagDao? bagDao,
    CustodyDao? custodyDao,
    FirestoreBagApi? api,
  })  : _outboxDao = outboxDao ?? OutboxDao(),
        _bagDao = bagDao ?? BagDao(),
        _custodyDao = custodyDao ?? CustodyDao(),
        _api = api ?? FirestoreBagApi();

  /// Push side: drain the outbox.
  Future<void> run() async {
    if (_running) return;
    _running = true;
    try {
      final batch = await _outboxDao.nextBatch();
      for (final op in batch) {
        try {
          final payload = jsonDecode(op.payloadJson) as Map<String, dynamic>;

          switch (op.opType) {
            case 'CREATE_BAG':
              await _api.upsertBag(payload);
              await _bagDao.markSynced(payload['id'] as String);
              break;
            case 'ADD_CUSTODY':
              await _api.upsertCustodyEvent(payload);
              await _custodyDao.markSynced(payload['id'] as String);
              break;
            default:
              debugPrint('SyncService: unknown op_type "${op.opType}", dropping op ${op.id}');
              await _outboxDao.delete(op.id);
              continue;
          }

          await _outboxDao.delete(op.id);
        } on TimeoutException catch (e) {
          // No answer in time: the network is effectively down. Record it
          // and stop the batch. The remaining operations haven't failed,
          // and trying each would burn 15 s apiece for nothing.
          await _outboxDao.recordFailure(op.id, 'Timed out: $e');
          break;
        } catch (e) {
          await _outboxDao.recordFailure(op.id, e.toString());
        }
      }
    } finally {
      _running = false;
    }
  }

  /// Pull side: fetch custody events other devices recorded for these
  /// bags and merge them into local SQLite. Events are immutable, so the
  /// merge is insert-if-absent — safe to run any number of times.
  Future<void> pullCustodyEvents(List<String> bagIds) async {
    if (bagIds.isEmpty) return;
    final remote = await _api.fetchCustodyEventsForBags(bagIds);
    for (final map in remote) {
      await _custodyDao.insertIfAbsent(CustodyEvent.fromFirestore(map));
    }
  }
}