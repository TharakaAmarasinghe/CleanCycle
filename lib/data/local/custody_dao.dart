import 'package:sqflite/sqflite.dart';
import '../../domain/models/custody_event.dart';
import 'database.dart';
import '../../core/constants.dart';

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

  /// A collector's own most recent events, newest first.
  Future<List<CustodyEvent>> getRecentByActor(String actorId, {int limit = 10}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'custody_events',
      where: 'actor_id = ?',
      whereArgs: [actorId],
      orderBy: 'occurred_at DESC',
      limit: limit,
    );
    return rows.map(CustodyEvent.fromMap).toList();
  }

  /// Today's counts, computed in SQL with GROUP BY rather than loading
  /// every row into Dart and counting there. Timestamps are stored as
  /// ISO-8601 local time, so comparing against the start of today as a
  /// string orders correctly.
  Future<({int collected, int delivered})> countTodayByActor(String actorId) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final rows = await db.rawQuery(
      'SELECT type, COUNT(*) AS c FROM custody_events '
          'WHERE actor_id = ? AND occurred_at >= ? GROUP BY type',
      [actorId, startOfDay],
    );
    var collected = 0;
    var delivered = 0;
    for (final r in rows) {
      final c = (r['c'] as int?) ?? 0;
      if (r['type'] == CustodyEventType.collected.name) collected = c;
      if (r['type'] == CustodyEventType.delivered.name) delivered = c;
    }
    return (collected: collected, delivered: delivered);
  }
}