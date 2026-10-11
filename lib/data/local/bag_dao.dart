import '../../domain/models/bag.dart';
import 'database.dart';

/// All SQL for the bags table lives here, and nowhere else. Repositories
/// call this — screens never touch SQL directly.
class BagDao {
  Future<void> insert(Bag bag) async {
    final db = await AppDatabase.instance.database;
    await db.insert('bags', bag.toMap());
  }

  Future<List<Bag>> getAllForOwner(String ownerId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'bags',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Bag.fromMap).toList();
  }

  Future<Bag?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('bags', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Bag.fromMap(rows.first);
  }

  Future<void> markSynced(String id) async {
    final db = await AppDatabase.instance.database;
    await db.update('bags', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// Every bag that hasn't been confirmed synced yet — used to show
  /// pending-sync chips without needing a live outbox join.
  Future<List<Bag>> getUnsynced() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('bags', where: 'synced = 0');
    return rows.map(Bag.fromMap).toList();
  }

  /// Finds a bag by the start of its id. The short code under the QR
  /// (first 4 characters) works as a manual-entry fallback.
  Future<Bag?> findByIdPrefix(String prefix) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'bags',
      where: 'id LIKE ?',
      whereArgs: ['${prefix.toLowerCase()}%'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Bag.fromMap(rows.first);
  }

  /// Bags with at least one Delivered custody event: the ones that count
  /// as recycled in the impact summary.
  Future<List<Bag>> getDeliveredForOwner(String ownerId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT bags.* FROM bags
      WHERE bags.owner_id = ?
        AND EXISTS (
          SELECT 1 FROM custody_events e
          WHERE e.bag_id = bags.id AND e.type = 'delivered'
        )
    ''', [ownerId]);
    return rows.map(Bag.fromMap).toList();
  }
}
