import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../domain/models/waste_report.dart';
import '../../state/report_state.dart';
import '../../widgets/report_location_text.dart';
import '../../widgets/report_status_chip.dart';

class ReportDetailScreen extends StatelessWidget {
  final WasteReport report;
  const ReportDetailScreen({super.key, required this.report});

  String _explain(ReportStatus s) => switch (s) {
    ReportStatus.pendingSync =>
    'Saved on this device. It will be sent when you are online.',
    ReportStatus.reported =>
    'Received. It has been sent and is waiting to be resolved.',
    ReportStatus.resolved => 'This report has been marked as resolved.',
  };

  Widget _row(BuildContext context, String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(child: value),
        ],
      ),
    );
  }

  Widget _photo(BuildContext context, WasteReport r) {
    final path = r.photoPath;
    Widget placeholder(String text) => Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_outlined, color: AppColors.primaryGreen, size: 36),
          const SizedBox(height: AppSpacing.sm),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );

    if (path == null) return placeholder('No photo attached');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _PhotoViewer(path: path)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Image.file(
          File(path),
          height: 240,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => placeholder('Photo not available on this device'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Look the report up again so its status updates live if a refresh
    // elsewhere changes it (for example it gets marked resolved).
    final r = context.watch<ReportState>().reports.firstWhere(
          (x) => x.id == report.id,
      orElse: () => report,
    );
    final secondary = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _photo(context, r),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(child: Text(r.category.label, style: Theme.of(context).textTheme.headlineMedium)),
                ReportStatusChip(status: r.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(_explain(r.status), style: secondary),
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    _row(context, 'Reported', Text(DateFormat('d MMM yyyy, HH:mm').format(r.createdAt))),
                    _row(context, 'Location', ReportLocationText(report: r)),
                    _row(
                      context,
                      'Description',
                      Text(
                        (r.description == null || r.description!.isEmpty)
                            ? 'No description'
                            : r.description!,
                      ),
                    ),
                    _row(context, 'Sync', Text(r.synced ? 'Synced' : 'Waiting to sync')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen photo with pinch to zoom.
class _PhotoViewer extends StatelessWidget {
  final String path;
  const _PhotoViewer({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(File(path)),
        ),
      ),
    );
  }
}