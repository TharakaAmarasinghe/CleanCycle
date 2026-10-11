import 'package:flutter/foundation.dart';

import '../../core/constants.dart';
import '../../data/repositories/bag_repository.dart';
import '../../domain/models/bag.dart';

/// Holds the current user's bags and impact figures in memory, backed by
/// BagRepository. Screens read this and call its methods; they never touch
/// the repository or sqflite directly.
class BagState extends ChangeNotifier {
  final BagRepository _repo = BagRepository();

  List<Bag> bags = [];
  Map<WasteCategory, double> recycledKg = {};
  bool isLoading = false;

  double get totalRecycledKg => recycledKg.values.fold(0.0, (sum, v) => sum + v);

  Future<void> refresh(String ownerId) async {
    isLoading = true;
    notifyListeners();
    bags = await _repo.getBagsForOwner(ownerId);
    recycledKg = await _repo.recycledWeightByCategory(ownerId);
    isLoading = false;
    notifyListeners();
  }

  Future<void> createBag({
    required String ownerId,
    required List<WasteCategory> categories,
    required double weightKg,
    String? notes,
  }) async {
    await _repo.createBag(
      ownerId: ownerId,
      categories: categories,
      weightKg: weightKg,
      notes: notes,
    );
    // Re-read from SQLite rather than appending in memory, so this list is
    // always a true reflection of the local database.
    await refresh(ownerId);
  }
}