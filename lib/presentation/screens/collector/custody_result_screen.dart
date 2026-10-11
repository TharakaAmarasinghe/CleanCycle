import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../domain/models/custody_event.dart';
import '../../state/sync_state.dart';
import '../../widgets/event_location_text.dart';

/// Makes it obvious the event is safely stored even with no signal.
/// Back navigation is disabled so a collector can't return to the
/// confirmation screen and record the same event twice.
class CustodyResultScreen extends StatelessWidget {
  final CustodyEvent event;
  const CustodyResultScreen({super.key, required this.event});

  Widget _statusRow(IconData icon, Color color, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: child),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncState>();
    final isCollected = event.type == CustodyEventType.collected;
    final shortId = event.bagId.substring(0, 4).toUpperCase();
    final hasLocation = event.latitude != null;

    final bool synced =
        sync.isOnline && !sync.isSyncing && sync.pendingCount == 0 && sync.failedCount == 0;

    final Widget syncRow;
    if (synced) {
      syncRow = _statusRow(Icons.cloud_done, AppColors.success, const Text('Synced'));
    } else if (sync.isSyncing) {
      syncRow = _statusRow(Icons.sync, AppColors.primaryGreen, const Text('Syncing…'));
    } else {
      syncRow = _statusRow(
        Icons.schedule,
        AppColors.accentAmber,
        const Text('Pending synchronization'),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.check_circle, size: 72, color: AppColors.primaryGreen),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  isCollected ? 'Collected' : 'Delivered',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Bag #$shortId · ${DateFormat('d MMM yyyy, HH:mm').format(event.occurredAt)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xxxl),
                _statusRow(Icons.check, AppColors.success, const Text('Recorded on this device')),
                if (hasLocation)
                  _statusRow(
                    Icons.location_on,
                    AppColors.success,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Location captured (±${event.accuracyMeters?.round() ?? '?'} m)'),
                        EventLocationText(
                          event: event,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                else
                  _statusRow(
                    Icons.location_off,
                    AppColors.accentAmber,
                    const Text('Location unavailable. Event recorded without coordinates.'),
                  ),
                syncRow,
                const SizedBox(height: AppSpacing.xxxl),
                ElevatedButton(
                  onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                  child: const Text('Scan next bag'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}