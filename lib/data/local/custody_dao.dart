import 'package:sqflite/sqflite.dart';

import '../../domain/models/custody_event.dart';
import 'database.dart';

class CustodyDao {
  Future<void> insert(CustodyEvent event) async {
    final db = await AppDatabase.instance.database;
    await db.insert('custody_events', event.toMap());
  }

  /// Used when merging events pulled from the server. Events are
  /// immutable, so "already have it" means "nothing to do" — ignoring the
  /// conflict makes the pull idempotent, like the push side.
  Future<void> insertIfAbsent(CustodyEvent event) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'custody_events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// The full event history for one bag, oldest first. Never query for
  /// "the" status; query for the events and derive it.
  Future<List<CustodyEvent>> getForBag(String bagId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'custody_events',
      where: 'bag_id = ?',
      whereArgs: [bagId],
      orderBy: 'occurred_at ASC',
    );
    return rows.map(CustodyEvent.fromMap).toList();
  }

  Future<void> updatePlaceName(String id, String placeName) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'custody_events',
      {'place_name': placeName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSynced(String id) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'custody_events',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CustodyEvent>> getUnsynced() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('custody_events', where: 'synced = 0');
    return rows.map(CustodyEvent.fromMap).toList();
  }
}