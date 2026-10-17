import 'package:flutter/foundation.dart';

import '../../data/repositories/bag_repository.dart';
import '../../domain/models/custody_event.dart';

/// What the Collector home shows: today's counts and the collector's own
/// latest events, all read from local SQLite.
class CollectorState extends ChangeNotifier {
  final BagRepository _repo = BagRepository();

  List<CustodyEvent> recent = [];
  int collectedToday = 0;
  int deliveredToday = 0;
  bool isLoading = false;

  Future<void> refresh(String actorId) async {
    isLoading = true;
    notifyListeners();
    recent = await _repo.getRecentEventsByActor(actorId);
    final counts = await _repo.todayCounts(actorId);
    collectedToday = counts.collected;
    deliveredToday = counts.delivered;
    isLoading = false;
    notifyListeners();
  }
}