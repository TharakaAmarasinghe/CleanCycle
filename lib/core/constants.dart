/// Waste categories used both by "Report Waste" and "Create Bag" — one
/// enum shared across both flows, since they're the same underlying idea.
enum WasteCategory {
  plastic,
  glass,
  paper,
  metal,
  illegalDumping,
  overflowingBin,
  eWaste,
  other,
}

extension WasteCategoryLabel on WasteCategory {
  String get label {
    switch (this) {
      case WasteCategory.plastic:
        return 'Plastic';
      case WasteCategory.glass:
        return 'Glass';
      case WasteCategory.paper:
        return 'Paper';
      case WasteCategory.metal:
        return 'Metal';
      case WasteCategory.illegalDumping:
        return 'Illegal dumping';
      case WasteCategory.overflowingBin:
        return 'Overflowing bin';
      case WasteCategory.eWaste:
        return 'E-waste';
      case WasteCategory.other:
        return 'Other';
    }
  }
}

/// Bag categories vs. report categories — bags only use physical
/// recyclable material types; reports use the issue types instead.
const bagCategories = [
  WasteCategory.plastic,
  WasteCategory.glass,
  WasteCategory.paper,
  WasteCategory.metal,
];

const reportCategories = [
  WasteCategory.illegalDumping,
  WasteCategory.overflowingBin,
  WasteCategory.eWaste,
  WasteCategory.other,
];

/// A bag's status is DERIVED from its custody events, never stored
/// directly — see CustodyEvent and the sync design notes.
enum CustodyEventType { collected, delivered }

enum BagStatus { created, collected, delivered, verified }

enum ReportStatus { reported, pendingSync, resolved }

/// User role, fixed at registration.
enum UserRole { household, collector }

/// Sync tuning — kept as named constants rather than magic numbers, so
/// the retry/backoff policy is documented in one place.
class SyncConfig {
  static const int outboxBatchSize = 20;
  static const int maxRetryAttempts = 5;
  static const List<int> backoffSeconds = [2, 4, 8, 16, 16];
}