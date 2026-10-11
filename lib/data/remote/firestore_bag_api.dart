import 'package:cloud_firestore/cloud_firestore.dart';

/// The remote half of bag sync. Every method here is idempotent: pushing
/// the same bag twice (e.g. after a retried operation whose first
/// acknowledgement was lost) overwrites identical data rather than
/// creating a duplicate — because we always .set() on the bag's own
/// client-generated id, never .add().
class FirestoreBagApi {
  final _bags = FirebaseFirestore.instance.collection('bags');
  final _custodyEvents = FirebaseFirestore.instance.collection('custody_events');
  /// A Firestore write doesn't fail when the network is down; it waits.
  /// Without a timeout, a push on a dead connection would never return.
  static const _pushTimeout = Duration(seconds: 15);

  Future<void> upsertBag(Map<String, dynamic> payload) async {
    await _bags
        .doc(payload['id'] as String)
        .set(payload, SetOptions(merge: true))
        .timeout(_pushTimeout);
  }

  Future<void> upsertCustodyEvent(Map<String, dynamic> payload) async {
    await _custodyEvents
        .doc(payload['id'] as String)
        .set(payload, SetOptions(merge: true))
        .timeout(_pushTimeout);
  }

  /// Pull side of sync — bags updated since the last successful pull,
  /// for a given owner. Used so a household sees custody events a
  /// collector's device wrote, without re-fetching everything every time.
  Future<List<Map<String, dynamic>>> fetchBagsUpdatedSince(
    String ownerId,
    DateTime since,
  ) async {
    final snapshot = await _bags
        .where('ownerId', isEqualTo: ownerId)
        .where('updatedAt', isGreaterThan: since.toIso8601String())
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> fetchCustodyEventsForBag(String bagId) async {
    final snapshot = await _custodyEvents.where('bagId', isEqualTo: bagId).get();
    return snapshot.docs.map((d) => d.data()).toList();
  }
  /// Pull side for custody events: all events for the given bags, using
  /// whereIn in chunks of 30 (Firestore's limit) instead of one query
  /// per bag — fewer round trips on a constrained connection.
  Future<List<Map<String, dynamic>>> fetchCustodyEventsForBags(List<String> bagIds) async {
    final results = <Map<String, dynamic>>[];
    for (var i = 0; i < bagIds.length; i += 30) {
      final end = i + 30 > bagIds.length ? bagIds.length : i + 30;
      final snapshot = await _custodyEvents.where('bagId', whereIn: bagIds.sublist(i, end)).get();
      results.addAll(snapshot.docs.map((d) => d.data()));
    }
    return results;
  }
}