import '../../core/constants.dart';

/// A report's photo is saved to local storage the moment it is taken, and
/// this model stores the file PATH, not the image bytes. The sync service
/// reads from that path when it uploads, so a killed app can't lose a
/// photo that hasn't synced yet.
class WasteReport {
  final String id;
  final String ownerId;
  final WasteCategory category;
  final String? photoPath;
  final double? latitude;
  final double? longitude;
  final String? description;
  final ReportStatus status;
  final DateTime createdAt;
  final bool synced;

  /// Reverse-geocoded name, cached locally. Presentation only: never
  /// synced, never on the write path. Coordinates are the evidence.
  final String? placeName;

  WasteReport({
    required this.id,
    required this.ownerId,
    required this.category,
    this.photoPath,
    this.latitude,
    this.longitude,
    this.description,
    this.status = ReportStatus.pendingSync,
    required this.createdAt,
    this.synced = false,
    this.placeName,
  });

  factory WasteReport.fromMap(Map<String, dynamic> map) {
    return WasteReport(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      category: WasteCategory.values.byName(map['category'] as String),
      photoPath: map['photo_path'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      description: map['description'] as String?,
      status: ReportStatus.values.byName(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      synced: (map['synced'] as int) == 1,
      placeName: map['place_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'owner_id': ownerId,
    'category': category.name,
    'photo_path': photoPath,
    'latitude': latitude,
    'longitude': longitude,
    'description': description,
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    'synced': synced ? 1 : 0,
    'place_name': placeName,
  };

  /// The report as the server stores it. The photo is NOT in here: it
  /// goes to a separate document, so pulling statuses stays light.
  Map<String, dynamic> toFirestore() => {
    'id': id,
    'ownerId': ownerId,
    'category': category.name,
    'latitude': latitude,
    'longitude': longitude,
    'description': description,
    'status': ReportStatus.reported.name,
    'createdAt': createdAt.toIso8601String(),
    'hasPhoto': photoPath != null,
  };
}