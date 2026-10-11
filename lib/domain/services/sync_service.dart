import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/constants.dart';
import '../../data/local/bag_dao.dart';
import '../../data/local/custody_dao.dart';
import '../../data/local/outbox_dao.dart';
import '../../data/local/report_dao.dart';
import '../../data/remote/firestore_bag_api.dart';
import '../../data/remote/firestore_report_api.dart';
import '../models/custody_event.dart';

/// The heart of the offline layer. run() drains the outbox; the pull
/// methods merge what other devices wrote. Nothing here schedules itself.
class SyncService {
  final OutboxDao _outboxDao;
  final BagDao _bagDao;
  final CustodyDao _custodyDao;
  final ReportDao _reportDao;
  final FirestoreBagApi _api;
  final FirestoreReportApi _reportApi;

  bool _running = false; // re-entrancy guard: never two pushes at once

  /// Firestore documents are capped at 1 MiB; leave headroom for fields.
  static const _maxPhotoChars = 900000;

  SyncService({
    OutboxDao? outboxDao,
    BagDao? bagDao,
    CustodyDao? custodyDao,
    ReportDao? reportDao,
    FirestoreBagApi? api,
    FirestoreReportApi? reportApi,
  })  : _outboxDao = outboxDao ?? OutboxDao(),
        _bagDao = bagDao ?? BagDao(),
        _custodyDao = custodyDao ?? CustodyDao(),
        _reportDao = reportDao ?? ReportDao(),
        _api = api ?? FirestoreBagApi(),
        _reportApi = reportApi ?? FirestoreReportApi();

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
            case 'SUBMIT_REPORT':
              {
                final doc = Map<String, dynamic>.from(payload);
                final photoPath = doc.remove('photoPath') as String?;
                final photo = await _readPhotoBase64(photoPath);
                // If the photo was too big or the file is gone, the report
                // still goes through, just without it.
                doc['hasPhoto'] = photo != null;
                await _reportApi.upsertReport(doc, photo);
                await _reportDao.markSynced(doc['id'] as String);
              }
              break;
            default:
              debugPrint('SyncService: unknown op_type "${op.opType}", dropping op ${op.id}');
              await _outboxDao.delete(op.id);
              continue;
          }

          await _outboxDao.delete(op.id);
        } on TimeoutException catch (e) {
          // No answer in time: the network is effectively down. Record it
          // and stop the batch; the rest haven't failed, and trying each
          // would burn the full timeout apiece for nothing.
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

  Future<String?> _readPhotoBase64(String? path) async {
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) {
      debugPrint('SyncService: photo missing at $path, syncing report without it');
      return null;
    }
    final encoded = base64Encode(await file.readAsBytes());
    if (encoded.length > _maxPhotoChars) {
      debugPrint('SyncService: photo too large (${encoded.length} chars), skipping it');
      return null;
    }
    return encoded;
  }

  /// Pull side: custody events other devices recorded. Events are
  /// immutable, so the merge is insert-if-absent and safe to repeat.
  Future<void> pullCustodyEvents(List<String> bagIds) async {
    if (bagIds.isEmpty) return;
    final remote = await _api.fetchCustodyEventsForBags(bagIds);
    for (final map in remote) {
      await _custodyDao.insertIfAbsent(CustodyEvent.fromFirestore(map));
    }
  }

  /// Pull side: reports someone has marked resolved on the server.
  Future<void> pullReportStatuses(String ownerId) async {
    final remote = await _reportApi.fetchReportsForOwner(ownerId);
    for (final map in remote) {
      if (map['status'] == ReportStatus.resolved.name) {
        await _reportDao.markResolved(map['id'] as String);
      }
    }
  }
}