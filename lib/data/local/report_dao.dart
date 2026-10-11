import '../../core/constants.dart';
import '../../domain/models/waste_report.dart';
import 'database.dart';

class ReportDao {
  Future<List<WasteReport>> getAllForOwner(String ownerId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'waste_reports',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'created_at DESC',
    );
    return rows.map(WasteReport.fromMap).toList();
  }

  /// Once the server has the report, it stops being "pending sync".
  Future<void> markSynced(String id) async {
    final db = await AppDatabase.instance.database;
    await db.update('waste_reports', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    await db.update(
      'waste_reports',
      {'status': ReportStatus.reported.name},
      where: 'id = ? AND status = ?',
      whereArgs: [id, ReportStatus.pendingSync.name],
    );
  }

  Future<void> markResolved(String id) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'waste_reports',
      {'status': ReportStatus.resolved.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updatePlaceName(String id, String placeName) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'waste_reports',
      {'place_name': placeName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}