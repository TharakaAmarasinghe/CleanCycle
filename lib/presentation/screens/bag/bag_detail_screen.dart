import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../data/repositories/bag_repository.dart';
import '../../../domain/models/bag.dart';
import '../../../domain/models/custody_event.dart';
import '../../state/sync_state.dart';
import '../../widgets/custody_timeline.dart';
import '../../widgets/event_location_text.dart';

class BagDetailScreen extends StatefulWidget {
  final Bag bag;
  const BagDetailScreen({super.key, required this.bag});

  @override
  State<BagDetailScreen> createState() => _BagDetailScreenState();
}

class _BagDetailScreenState extends State<BagDetailScreen> {
  final BagRepository _repo = BagRepository();
  List<CustodyEvent>? _events;

  @override
  void initState() {
    super.initState();
    // Local-first: show what's on this device immediately, then pull
    // anything other devices recorded and refresh.
    _loadLocal();
    _pullThenReload();
  }

  Future<void> _loadLocal() async {
    final events = await _repo.getCustodyEvents(widget.bag.id);
    if (!mounted) return;
    setState(() => _events = events);
  }

  Future<void> _pullThenReload() async {
    final sync = context.read<SyncState>();
    await sync.pullCustodyEvents([widget.bag.id]);
    await _loadLocal();
  }

  String _statusLabel(BagStatus s) => switch (s) {
    BagStatus.created => 'Created',
    BagStatus.collected => 'Collected',
    BagStatus.delivered => 'Delivered',
    BagStatus.verified => 'Verified',
  };

  String _short(String s) => s.length <= 6 ? s : s.substring(0, 6);

  Widget _detailRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }

  void _showEventDetails(CustodyEvent e) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          0,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              e.type == CustodyEventType.collected ? 'Collected' : 'Delivered',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _detailRow('When', Text(DateFormat('d MMM yyyy, HH:mm').format(e.occurredAt))),
            _detailRow('Recorded by', Text('Collector ${_short(e.actorId)}')),
            _detailRow(
              'Location',
              e.latitude == null
                  ? const Text('No location recorded')
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventLocationText(event: e),
                  Text(
                    'Accuracy ±${e.accuracyMeters?.round() ?? '?'} m',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            _detailRow('Sync', Text(e.synced ? 'Synced' : 'Waiting to sync')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bag = widget.bag;
    final events = _events;
    final status = deriveBagStatus(events ?? const <CustodyEvent>[]);

    return Scaffold(
      appBar: AppBar(title: Text('Bag #${bag.id.substring(0, 4).toUpperCase()}')),
      body: RefreshIndicator(
        onRefresh: _pullThenReload,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.all(AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      '#${bag.id.substring(0, 4).toUpperCase()}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // The QR encodes ONLY the bag's UUID.
                    QrImageView(
                      data: bag.id,
                      version: QrVersions.auto,
                      size: 180,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Show this to your collector at pickup',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${bag.weightKg.toStringAsFixed(1)} kg · ${bag.categories.map((c) => c.label).join(', ')}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Icon(
                      bag.synced ? Icons.check_circle : Icons.cloud_off,
                      size: 18,
                      color: bag.synced ? AppColors.success : AppColors.accentAmber,
                    ),
                  ],
                ),
              ),
              if (bag.notes != null && bag.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                  child: Text(bag.notes!, style: Theme.of(context).textTheme.bodyMedium),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                child: Text(
                  'Current status: ${_statusLabel(status)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text('Custody journey', style: Theme.of(context).textTheme.labelLarge),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: events == null
                    ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
                    : CustodyTimeline(
                  createdAt: bag.createdAt,
                  events: events,
                  onEventTap: _showEventDetails,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}