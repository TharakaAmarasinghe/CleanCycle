import '../../core/constants.dart';

/// A custody event is an immutable fact — "this bag was collected by
/// this person at this time and place." Bags never have their status
/// updated directly; the status is DERIVED from this event history.
///
/// Two devices (household + collector) each inserting a *new* event
/// produces a union on sync, not a write conflict.
class CustodyEvent {
  final String id; // client-generated UUID
  final String bagId;
  final String actorId;
  final CustodyEventType type;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime occurredAt; // device clock at the moment of the scan
  final bool synced;

  /// Reverse-geocoded name, cached locally. NOT part of the evidence and
  /// never synced: each device resolves it itself when displaying the
  /// event. Coordinates are the source of truth.
  final String? placeName;

  CustodyEvent({
    required this.id,
    required this.bagId,
    required this.actorId,
    required this.type,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    required this.occurredAt,
    this.synced = false,
    this.placeName,
  });

  CustodyEvent copyWith({bool? synced, String? placeName}) {
    return CustodyEvent(
      id: id,
      bagId: bagId,
      actorId: actorId,
      type: type,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      occurredAt: occurredAt,
      synced: synced ?? this.synced,
      placeName: placeName ?? this.placeName,
    );
  }

  factory CustodyEvent.fromMap(Map<String, dynamic> map) {
    return CustodyEvent(
      id: map['id'] as String,
      bagId: map['bag_id'] as String,
      actorId: map['actor_id'] as String,
      type: CustodyEventType.values.byName(map['type'] as String),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      accuracyMeters: (map['accuracy_m'] as num?)?.toDouble(),
      occurredAt: DateTime.parse(map['occurred_at'] as String),
      synced: (map['synced'] as int) == 1,
      placeName: map['place_name'] as String?,
    );
  }

  /// Builds an event from a Firestore document pulled from the server.
  /// Anything that came FROM the server is by definition already synced.
  factory CustodyEvent.fromFirestore(Map<String, dynamic> map) {
    return CustodyEvent(
      id: map['id'] as String,
      bagId: map['bagId'] as String,
      actorId: map['actorId'] as String,
      type: CustodyEventType.values.byName(map['type'] as String),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble(),
      occurredAt: DateTime.parse(map['occurredAt'] as String),
      synced: true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'bag_id': bagId,
    'actor_id': actorId,
    'type': type.name,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy_m': accuracyMeters,
    'occurred_at': occurredAt.toIso8601String(),
    'synced': synced ? 1 : 0,
    'place_name': placeName,
  };

  /// What gets pushed to Firestore. Deliberately excludes placeName.
  Map<String, dynamic> toFirestore() => {
    'id': id,
    'bagId': bagId,
    'actorId': actorId,
    'type': type.name,
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracyMeters,
    'occurredAt': occurredAt.toIso8601String(),
  };
}

/// Derives a bag's current status from its event history, ordered by
/// occurredAt. Status is always computed, never stored.
BagStatus deriveBagStatus(List<CustodyEvent> events) {
  if (events.isEmpty) return BagStatus.created;
  final sorted = [...events]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  final latest = sorted.last;
  switch (latest.type) {
    case CustodyEventType.collected:
      return BagStatus.collected;
    case CustodyEventType.delivered:
      return BagStatus.delivered;
  }
}