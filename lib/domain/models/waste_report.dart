import '../../core/constants.dart';

/// A photo captured offline is saved to local device storage immediately,
/// and this model stores the file PATH, not the image bytes — the sync
/// service reads from that path when it eventually uploads. This is what
/// stops a killed app from losing a photo that hasn't synced yet.
class WasteReport {
  final String id;
  final String ownerId;
  final WasteCategory category;
  final String? photoPath; // local file path, not the image itself
  final double? latitude;
  final double? longitude;
  final String? description;
  final ReportStatus status;
  final DateTime createdAt;
  final bool synced;

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
  });

  WasteReport copyWith({ReportStatus? status, bool? synced}) {
    return WasteReport(
      id: id,
      ownerId: ownerId,
      category: category,
      photoPath: photoPath,
      latitude: latitude,
      longitude: longitude,
      description: description,
      status: status ?? this.status,
      createdAt: createdAt,
      synced: synced ?? this.synced,
    );
  }

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
      };
}