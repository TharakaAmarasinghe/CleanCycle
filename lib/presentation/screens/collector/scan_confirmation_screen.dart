import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../data/repositories/bag_repository.dart';
import '../../../domain/models/bag.dart';
import '../../../domain/services/location_service.dart';
import '../../state/auth_state.dart';
import '../../state/sync_state.dart';
import 'custody_result_screen.dart';
import '../../state/collector_state.dart';

/// A custody event is NEVER created silently. Scanning only brings the
/// collector here; nothing is recorded until they press one of the two
/// explicit confirm buttons.
class ScanConfirmationScreen extends StatefulWidget {
  final String bagId;
  const ScanConfirmationScreen({super.key, required this.bagId});

  @override
  State<ScanConfirmationScreen> createState() => _ScanConfirmationScreenState();
}

class _ScanConfirmationScreenState extends State<ScanConfirmationScreen> {
  final BagRepository _repo = BagRepository();
  final LocationService _location = LocationService();
  late Future<(Bag?, BagStatus)> _infoFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _infoFuture = _load();
  }

  Future<(Bag?, BagStatus)> _load() async {
    final bag = await _repo.getBag(widget.bagId);
    final status = await _repo.getBagStatus(widget.bagId);
    return (bag, status);
  }

  Future<void> _confirm(CustodyEventType type) async {
    final auth = context.read<AuthState>();
    final sync = context.read<SyncState>();
    final collector = context.read<CollectorState>();
    final actorId = auth.currentUser!.id;
    setState(() => _saving = true);

    // One-shot fix. Returns null rather than throwing if location is
    // denied or unavailable, so the event is still recorded.
    final loc = await _location.getCurrentLocation();

    final event = await _repo.addCustodyEvent(
      bagId: widget.bagId,
      actorId: actorId,
      type: type,
      latitude: loc?.latitude,
      longitude: loc?.longitude,
      accuracyMeters: loc?.accuracyMeters,
    );
    await collector.refresh(actorId);
    sync.triggerSync();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CustodyResultScreen(event: event)),
    );
  }

  String _statusLabel(BagStatus s) => switch (s) {
    BagStatus.created => 'Created',
    BagStatus.collected => 'Collected',
    BagStatus.delivered => 'Delivered',
    BagStatus.verified => 'Verified',
  };

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: AppSpacing.lg),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shortId = widget.bagId.substring(0, 4).toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm event')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FutureBuilder<(Bag?, BagStatus)>(
                future: _infoFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final (bag, status) = snapshot.data!;
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _row('Bag', '#$shortId'),
                        if (bag != null) ...[
                          _row('Contents', bag.categories.map((c) => c.label).join(', ')),
                          _row('Est. weight', '${bag.weightKg.toStringAsFixed(1)} kg'),
                        ] else
                          _row('Details', 'Not available on this device'),
                        _row('Current status', _statusLabel(status)),
                        _row('Location', 'Captured when you confirm'),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Nothing is recorded until you confirm below. This works offline; '
                    'the event syncs when a connection returns.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: Text('Capturing location and saving…')),
                )
              else ...[
                ElevatedButton(
                  onPressed: () => _confirm(CustodyEventType.collected),
                  child: const Text('Confirm Collected'),
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkGreen),
                  onPressed: () => _confirm(CustodyEventType.delivered),
                  child: const Text('Confirm Delivered'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}