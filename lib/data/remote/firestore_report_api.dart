import 'package:cloud_firestore/cloud_firestore.dart';

/// Remote half of report sync. Idempotent like the bag API: documents are
/// written with set() on the client-generated id, never add().
class FirestoreReportApi {
  final _reports = FirebaseFirestore.instance.collection('reports');
  final _photos = FirebaseFirestore.instance.collection('report_photos');

  /// Writes the report and its photo in ONE batch, so there is never a
  /// report claiming a photo that didn't arrive. Photos are base64 text
  /// in their own document because Firebase Storage needs a paid plan;
  /// compression at capture keeps them well under Firestore's 1 MiB
  /// document limit.
  ///
  /// A Firestore write waits rather than failing when offline, so this
  /// is bounded by a timeout.
  Future<void> upsertReport(Map<String, dynamic> report, String? photoBase64) async {
    final id = report['id'] as String;
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_reports.doc(id), report, SetOptions(merge: true));
    if (photoBase64 != null) {
      batch.set(_photos.doc(id), {'id': id, 'base64': photoBase64});
    }
    await batch.commit().timeout(const Duration(seconds: 20));
  }

  /// Light query: report documents carry no photo bytes.
  Future<List<Map<String, dynamic>>> fetchReportsForOwner(String ownerId) async {
    final snapshot = await _reports
        .where('ownerId', isEqualTo: ownerId)
        .get()
        .timeout(const Duration(seconds: 15));
    return snapshot.docs.map((d) => d.data()).toList();
  }
}