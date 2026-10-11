import 'package:flutter/foundation.dart';

import '../../core/constants.dart';
import '../../data/repositories/report_repository.dart';
import '../../domain/models/waste_report.dart';

class ReportState extends ChangeNotifier {
  final ReportRepository _repo = ReportRepository();

  List<WasteReport> reports = [];
  bool isLoading = false;

  Future<void> refresh(String ownerId) async {
    isLoading = true;
    notifyListeners();
    reports = await _repo.getReports(ownerId);
    isLoading = false;
    notifyListeners();
  }

  Future<void> createReport({
    required String ownerId,
    required WasteCategory category,
    String? description,
    double? latitude,
    double? longitude,
    String? placeName,
    String? photoSourcePath,
  }) async {
    await _repo.createReport(
      ownerId: ownerId,
      category: category,
      description: description,
      latitude: latitude,
      longitude: longitude,
      placeName: placeName,
      photoSourcePath: photoSourcePath,
    );
    await refresh(ownerId);
  }
}