import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../screens/sync/sync_centre_screen.dart';
import '../state/sync_state.dart';

enum SyncPhase { hidden, syncing, failed, offline }

/// Custom component: the visual layer, fully controlled by its inputs.
///
/// Properties
///   phase         which of the four states to render
///   pendingCount  operations waiting in the outbox
///   failedCount   operations that exhausted their retries
/// Events
///   onTap         the banner was tapped (opens the Sync Centre)
///   onRetry       the Retry action was tapped (failed phase only)
///
/// Phases: hidden (online and nothing to report), syncing (green),
/// failed (red, with Retry), offline (amber). Offline is deliberately
/// amber, not red: being offline is normal, not an error.
class SyncStatusView extends StatelessWidget {
  final SyncPhase phase;
  final int pendingCount;
  final int failedCount;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  const SyncStatusView({
    super.key,
    required this.phase,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.onTap,
    this.onRetry,
  });

  String _plural(int n) => n == 1 ? 'item' : 'items';

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case SyncPhase.hidden:
        return const SizedBox.shrink();
      case SyncPhase.syncing:
        return _banner(
          color: AppColors.primaryGreen,
          bg: AppColors.lightGreen,
          icon: Icons.sync,
          text: 'Syncing $pendingCount ${_plural(pendingCount)}…',
        );
      case SyncPhase.failed:
        return _banner(
          color: AppColors.error,
          bg: AppColors.error.withValues(alpha: 0.1),
          icon: Icons.error_outline,
          text: "$failedCount ${_plural(failedCount)} couldn't sync",
          actionLabel: 'Retry',
        );
      case SyncPhase.offline:
        return _banner(
          color: AppColors.accentAmber,
          bg: AppColors.accentAmber.withValues(alpha: 0.12),
          icon: Icons.cloud_off,
          text: pendingCount > 0
              ? 'Offline · Changes saved locally ($pendingCount pending)'
              : 'Offline · Changes saved locally',
        );
    }
  }

  Widget _banner({
    required Color color,
    required Color bg,
    required IconData icon,
    required String text,
    String? actionLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),
                if (actionLabel != null)
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Connects SyncStatusView to the app's SyncState. Screens use this.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncState>();

    final SyncPhase phase;
    if (sync.isSyncing) {
      phase = SyncPhase.syncing;
    } else if (sync.failedCount > 0) {
      phase = SyncPhase.failed;
    } else if (!sync.isOnline) {
      phase = SyncPhase.offline;
    } else {
      phase = SyncPhase.hidden;
    }

    return SyncStatusView(
      phase: phase,
      pendingCount: sync.pendingCount,
      failedCount: sync.failedCount,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SyncCentreScreen()),
      ),
      onRetry: () => sync.retryFailed(),
    );
  }
}