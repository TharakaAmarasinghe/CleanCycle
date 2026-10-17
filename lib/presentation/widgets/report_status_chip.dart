import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

String reportStatusLabel(ReportStatus status) => switch (status) {
  ReportStatus.pendingSync => 'Pending sync',
  ReportStatus.reported => 'Reported',
  ReportStatus.resolved => 'Resolved',
};

/// Pending sync is amber (offline, not an error), Reported is green,
/// Resolved is solid dark green.
class ReportStatusChip extends StatelessWidget {
  final ReportStatus status;
  const ReportStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    switch (status) {
      case ReportStatus.pendingSync:
        fg = AppColors.accentAmber;
        bg = AppColors.accentAmber.withValues(alpha: 0.12);
      case ReportStatus.reported:
        fg = AppColors.primaryGreen;
        bg = AppColors.lightGreen;
      case ReportStatus.resolved:
        fg = Colors.white;
        bg = AppColors.darkGreen;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(
        reportStatusLabel(status),
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}