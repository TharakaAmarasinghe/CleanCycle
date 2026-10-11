import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../domain/models/outbox_op.dart';
import '../../domain/models/waste_report.dart';
import '../../domain/services/geocoding_service.dart';
import '../local/database.dart';
import '../local/report_dao.dart';

/// Same pattern as BagRepository: local write plus outbox entry, in ONE
/// transaction. Screens never touch SQL, files or the outbox directly.
class ReportRepository {
  final ReportDao _reportDao = ReportDao();
  final GeocodingService _geocoding = GeocodingService();
  final _uuid = const Uuid();

  Future<WasteReport> createReport({
    required String ownerId,
    required WasteCategory category,
    String? description,
    double? latitude,
    double? longitude,
    String? placeName,
    String? photoSourcePath,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    // The camera's output sits in a cache folder the OS may clear, so
    // copy it somewhere permanent before anything refers to it.
    String? storedPhotoPath;
    if (photoSourcePath != null) {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'report_photos'));
      await dir.create(recursive: true);
      storedPhotoPath = p.join(dir.path, '$id.jpg');
      await File(photoSourcePath).copy(storedPhotoPath);
    }

    final report = WasteReport(
      id: id,
      ownerId: ownerId,
      category: category,
      photoPath: storedPhotoPath,
      latitude: latitude,
      longitude: longitude,
      description: description,
      createdAt: now,
      placeName: placeName,
    );

    // The outbox payload carries the local photo PATH. The sync service
    // reads the file at upload time, so the image bytes never sit in the
    // outbox table.
    final payload = {...report.toFirestore(), 'photoPath': storedPhotoPath};

    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.insert('waste_reports', report.toMap());
      await txn.insert(
        'outbox',
        OutboxOp(
          id: _uuid.v4(),
          opType: 'SUBMIT_REPORT',
          payloadJson: jsonEncode(payload),
          createdAt: now,
        ).toMap(),
      );
    });

    return report;
  }

  Future<List<WasteReport>> getReports(String ownerId) => _reportDao.getAllForOwner(ownerId);

  /// Cached place name, or a best-effort lookup (online only) that is then
  /// cached. Null means "show coordinates instead".
  Future<String?> placeNameFor(WasteReport report) async {
    if (report.placeName != null) return report.placeName;
    final lat = report.latitude;
    final lon = report.longitude;
    if (lat == null || lon == null) return null;

    final name = await _geocoding.placeName(lat, lon);
    if (name != null) await _reportDao.updatePlaceName(report.id, name);
    return name;
  }
}