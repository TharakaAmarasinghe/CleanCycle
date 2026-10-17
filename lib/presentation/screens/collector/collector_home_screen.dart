import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../domain/models/custody_event.dart';
import '../../state/auth_state.dart';
import '../../state/collector_state.dart';
import '../../state/sync_state.dart';
import '../../widgets/sync_status_banner.dart';
import '../sync/sync_centre_screen.dart';
import 'scanner_screen.dart';

class CollectorHomeScreen extends StatefulWidget {
  const CollectorHomeScreen({super.key});

  @override
  State<CollectorHomeScreen> createState() => _CollectorHomeScreenState();
}

class _CollectorHomeScreenState extends State<CollectorHomeScreen> {
  bool _wasSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final user = context.read<AuthState>().currentUser;
    if (user == null) return;
    await context.read<CollectorState>().refresh(user.id);
  }

  /// Local first (instant), then push anything waiting, then re-read so
  /// the sync icons catch up.
  Future<void> _pullToRefresh() async {
    await _reload();
    if (!mounted) return;
    await context.read<SyncState>().triggerSync();
    if (!mounted) return;
    await _reload();
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Widget _eventTile(CustodyEvent e) {
    final isCollected = e.type == CustodyEventType.collected;
    final shortId = e.bagId.substring(0, 4).toUpperCase();
    final when = _isToday(e.occurredAt)
        ? DateFormat('HH:mm').format(e.occurredAt)
        : DateFormat('d MMM, HH:mm').format(e.occurredAt);

    // Display only: use a place name if one is already cached, otherwise
    // coordinates. No network lookups here; a list of ten rows would fire
    // ten geocoding requests every time the screen opens.
    final String place;
    if (e.placeName != null) {
      place = e.placeName!;
    } else if (e.latitude != null && e.longitude != null) {
      place = '${e.latitude!.toStringAsFixed(3)}, ${e.longitude!.toStringAsFixed(3)}';
    } else {
      place = 'No location recorded';
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.lightGreen,
          child: Icon(
            isCollected ? Icons.shopping_bag_outlined : Icons.local_shipping_outlined,
            color: AppColors.primaryGreen,
          ),
        ),
        title: Text('Bag #$shortId'),
        subtitle: Text('${isCollected ? 'Collected' : 'Delivered'} · $when\n$place'),
        isThreeLine: true,
        trailing: Icon(
          e.synced ? Icons.check_circle : Icons.cloud_off,
          size: 20,
          color: e.synced ? AppColors.success : AppColors.accentAmber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final collector = context.watch<CollectorState>();
    final sync = context.watch<SyncState>();

    // When a sync run finishes, re-read so the icons flip to synced
    // without a manual refresh. Fires once per run, so it can't loop:
    // the re-read changes CollectorState, not the sync flag.
    if (_wasSyncing && !sync.isSyncing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reload();
      });
    }
    _wasSyncing = sync.isSyncing;

    final waiting = sync.pendingCount + sync.failedCount;

    return Scaffold(
      appBar: AppBar(
        title: Text('Collector · ${auth.currentUser?.name ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync centre',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SyncCentreScreen()),
            ),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => auth.signOut()),
        ],
      ),
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _pullToRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Row(
                    children: [
                      Expanded(child: _StatBox(value: '${collector.collectedToday}', label: 'Collected today')),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _StatBox(value: '${collector.deliveredToday}', label: 'Delivered today')),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _StatBox(value: '$waiting', label: 'Waiting to sync')),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(72)),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScannerScreen()),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 28),
                    label: const Text('Scan QR'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Recent custody events', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  if (collector.recent.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        collector.isLoading
                            ? 'Loading…'
                            : 'No scans yet. Scan a bag tag to record your first custody event.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    for (final e in collector.recent) _eventTile(e),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}