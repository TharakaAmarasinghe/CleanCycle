import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../domain/models/waste_report.dart';
import '../../state/auth_state.dart';
import '../../state/report_state.dart';
import '../../state/sync_state.dart';
import '../../widgets/report_location_text.dart';
import '../../widgets/sync_status_banner.dart';
import 'report_waste_screen.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  /// Local first (instant), then push anything waiting, then pick up
  /// reports marked resolved on the server, then re-read.
  Future<void> _refresh() async {
    final user = context.read<AuthState>().currentUser;
    if (user == null) return;
    final reportState = context.read<ReportState>();
    final sync = context.read<SyncState>();

    await reportState.refresh(user.id);
    await sync.triggerSync();
    await sync.pullReportStatuses(user.id);
    if (!mounted) return;
    await reportState.refresh(user.id);
  }

  Widget _thumb(WasteReport r) {
    Widget placeholder(IconData icon) => Container(
      width: 72,
      height: 72,
      color: AppColors.lightGreen,
      child: Icon(icon, color: AppColors.primaryGreen),
    );
    final path = r.photoPath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: path == null
          ? placeholder(Icons.no_photography_outlined)
          : Image.file(
        File(path),
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        // Decode at thumbnail size, not full size: far less memory
        // for a long list of photos.
        cacheWidth: 216,
        errorBuilder: (context, error, stack) => placeholder(Icons.broken_image_outlined),
      ),
    );
  }

  Widget _statusChip(ReportStatus status) {
    final Color fg;
    final Color bg;
    final String label;
    switch (status) {
      case ReportStatus.pendingSync:
        fg = AppColors.accentAmber;
        bg = AppColors.accentAmber.withValues(alpha: 0.12);
        label = 'Pending sync';
      case ReportStatus.reported:
        fg = AppColors.primaryGreen;
        bg = AppColors.lightGreen;
        label = 'Reported';
      case ReportStatus.resolved:
        fg = Colors.white;
        bg = AppColors.darkGreen;
        label = 'Resolved';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _card(WasteReport r) {
    final secondary = Theme.of(context).textTheme.bodyMedium;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _thumb(r),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.category.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.xs),
                  ReportLocationText(report: r, style: secondary),
                  Text(DateFormat('d MMM yyyy, HH:mm').format(r.createdAt), style: secondary),
                  if (r.description != null && r.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(r.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  _statusChip(r.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportState = context.watch<ReportState>();
    final reports = reportState.reports;

    return Scaffold(
      appBar: AppBar(title: const Text('My reports')),
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: reports.isEmpty
                  ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      reportState.isLoading
                          ? 'Loading…'
                          : 'No reports yet. Report illegal dumping, an overflowing bin or e-waste with the + button.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: reports.length,
                itemBuilder: (context, i) => _card(reports[i]),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Report waste',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReportWasteScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}