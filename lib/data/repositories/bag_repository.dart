import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../domain/models/bag.dart';
import '../../domain/models/custody_event.dart';
import '../../domain/models/outbox_op.dart';
import '../../domain/services/geocoding_service.dart';
import '../../core/constants.dart';
import '../local/bag_dao.dart';
import '../local/custody_dao.dart';
import '../local/database.dart';

/// The ONLY thing in the app that knows both SQLite and the outbox exist.
/// Screens and state classes call this; they never touch a DAO directly.
class BagRepository {
  final BagDao _bagDao = BagDao();
  final CustodyDao _custodyDao = CustodyDao();
  final GeocodingService _geocoding = GeocodingService();
  final _uuid = const Uuid();

  /// Creates a bag locally and enqueues the sync operation — both writes
  /// inside ONE transaction, so either both happened or neither did.
  Future<Bag> createBag({
    required String ownerId,
    required List<WasteCategory> categories,
    required double weightKg,
    String? notes,
  }) async {
    final now = DateTime.now();
    final bag = Bag(
      id: _uuid.v4(),
      ownerId: ownerId,
      categories: categories,
      weightKg: weightKg,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      synced: false,
    );

    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.insert('bags', bag.toMap());
      await txn.insert(
        'outbox',
        OutboxOp(
          id: _uuid.v4(),
          opType: 'CREATE_BAG',
          payloadJson: jsonEncode(bag.toFirestore()),
          createdAt: now,
        ).toMap(),
      );
    });

    return bag;
  }

  /// Same atomic pattern for a custody event — always a new event,
  /// never a status update.
  Future<CustodyEvent> addCustodyEvent({
    required String bagId,
    required String actorId,
    required CustodyEventType type,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
  }) async {
    final now = DateTime.now();
    final event = CustodyEvent(
      id: _uuid.v4(),
      bagId: bagId,
      actorId: actorId,
      type: type,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      occurredAt: now,
      synced: false,
    );

    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.insert('custody_events', event.toMap());
      await txn.insert(
        'outbox',
        OutboxOp(
          id: _uuid.v4(),
          opType: 'ADD_CUSTODY',
          payloadJson: jsonEncode(event.toFirestore()),
          createdAt: now,
        ).toMap(),
      );
    });

    return event;
  }

  Future<List<Bag>> getBagsForOwner(String ownerId) => _bagDao.getAllForOwner(ownerId);

  Future<Bag?> getBag(String id) => _bagDao.getById(id);

  /// Manual-entry fallback: finds a bag by the first characters of its id.
  Future<Bag?> findBagByCode(String code) => _bagDao.findByIdPrefix(code);

  Future<List<CustodyEvent>> getCustodyEvents(String bagId) => _custodyDao.getForBag(bagId);

  /// A bag's status is always computed from its event history.
  Future<BagStatus> getBagStatus(String bagId) async {
    final events = await _custodyDao.getForBag(bagId);
    return deriveBagStatus(events);
  }

  /// Place name for an event: the cached one if we have it, otherwise a
  /// best-effort lookup (online only) that is then cached. Returns null
  /// when there are no coordinates or the lookup can't complete, and the
  /// caller shows coordinates instead.
  Future<String?> placeNameFor(CustodyEvent event) async {
    if (event.placeName != null) return event.placeName;
    final lat = event.latitude;
    final lon = event.longitude;
    if (lat == null || lon == null) return null;

    final name = await _geocoding.placeName(lat, lon);
    if (name != null) await _custodyDao.updatePlaceName(event.id, name);
    return name;
  }

  /// Recycled weight per category: bags that have a Delivered event. A bag
  /// stores one total weight, not a per-category split, so its weight is
  /// divided evenly across its categories. This is an approximation, and
  /// the UI and the document both say so.
  Future<Map<WasteCategory, double>> recycledWeightByCategory(String ownerId) async {
    final delivered = await _bagDao.getDeliveredForOwner(ownerId);
    final result = <WasteCategory, double>{};
    for (final bag in delivered) {
      if (bag.categories.isEmpty) continue;
      final share = bag.weightKg / bag.categories.length;
      for (final c in bag.categories) {
        result[c] = (result[c] ?? 0) + share;
      }
    }
    return result;
  }

  /// A collector's own latest events, for the Collector home.
  Future<List<CustodyEvent>> getRecentEventsByActor(String actorId, {int limit = 10}) =>
      _custodyDao.getRecentByActor(actorId, limit: limit);

  Future<({int collected, int delivered})> todayCounts(String actorId) =>
      _custodyDao.countTodayByActor(actorId);
}