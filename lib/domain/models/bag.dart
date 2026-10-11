import '../../core/constants.dart';

/// A bag is created locally and always has an ID before it ever reaches
/// the server — this is what makes offline creation possible, and what
/// lets the QR code exist before the first sync.
class Bag {
  final String id; // client-generated UUID
  final String ownerId;
  final List<WasteCategory> categories;
  final double weightKg;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;

  Bag({
    required this.id,
    required this.ownerId,
    required this.categories,
    required this.weightKg,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.synced = false,
  });

  Bag copyWith({bool? synced, DateTime? updatedAt}) {
    return Bag(
      id: id,
      ownerId: ownerId,
      categories: categories,
      weightKg: weightKg,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }

  factory Bag.fromMap(Map<String, dynamic> map) {
    return Bag(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      categories: (map['categories'] as String)
          .split(',')
          .where((s) => s.isNotEmpty)
          .map((s) => WasteCategory.values.byName(s))
          .toList(),
      weightKg: (map['weight_kg'] as num).toDouble(),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      synced: (map['synced'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'owner_id': ownerId,
        'categories': categories.map((c) => c.name).join(','),
        'weight_kg': weightKg,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'synced': synced ? 1 : 0,
      };

  /// What gets pushed to Firestore — deliberately similar to toMap but
  /// kept separate, since the two schemas are allowed to diverge later
  /// (e.g. if Firestore needs a field the local table doesn't).
  Map<String, dynamic> toFirestore() => {
        'id': id,
        'ownerId': ownerId,
        'categories': categories.map((c) => c.name).toList(),
        'weightKg': weightKg,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}