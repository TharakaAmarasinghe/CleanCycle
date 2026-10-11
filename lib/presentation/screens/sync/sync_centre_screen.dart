import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../../../data/local/outbox_dao.dart';
import '../../../domain/models/outbox_op.dart';
import '../../state/sync_state.dart';

/// Shows exactly what the outbox holds, so the offline mechanism is
/// visible instead of something the user has to trust.
class SyncCentreScreen extends StatelessWidget {
  const SyncCentreScreen({super.key});

  static final OutboxDao _dao = OutboxDao();

  Future<(List<OutboxOp>, List<OutboxOp>)> _load() async {
    final pending = await _dao.getPending();
    final failed = await _dao.getFailed();
    return (pending, failed);
  }

  String _typeLabel(String opType) => switch (opType) {
    'CREATE_BAG' => 'Bag',
    'ADD_CUSTODY' => 'Custody event',
    'SUBMIT_REPORT' => 'Waste report',
    _ => opType,
  };

  String _shortId(OutboxOp op) {
    try {
      final map = jsonDecode(op.payloadJson) as Map<String, dynamic>;
      return '#${(map['id'] as String).substring(0, 4).toUpperCase()}';
    } catch (_) {
      return '';
    }
  }

  Widget _statRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), value],
      ),
    );
  }

  Widget _opTile(BuildContext context, OutboxOp op, {required bool failed}) {
    final when = DateFormat('d MMM, HH:mm').format(op.createdAt);
    final String detail;
    if (failed) {
      detail = "Gave up after ${op.attempts} attempts · ${op.lastError ?? 'unknown error'}";
    } else if (op.attempts > 0) {
      detail = 'Queued $when · retrying (attempt ${op.attempts})';
    } else {
      detail = 'Queued $when · waiting to sync';
    }
    return ListTile(
      dense: true,
      leading: Icon(
        failed ? Icons.error_outline : Icons.schedule,
        color: failed ? AppColors.error : AppColors.accentAmber,
      ),
      title: Text('${_typeLabel(op.opType)} ${_shortId(op)}'),
      subtitle: Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncState>();
    final last = sync.lastSyncAt;

    return Scaffold(
      appBar: AppBar(title: const Text('Sync centre')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _statRow(
                  'Connection',
                  Text(
                    sync.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: sync.isOnline ? AppColors.success : AppColors.accentAmber,
                    ),
                  ),
                ),
                _statRow(
                  'Last sync (this session)',
                  Text(last == null ? 'Not yet' : DateFormat('d MMM, HH:mm').format(last)),
                ),
                _statRow('Waiting to sync', Text('${sync.pendingCount}')),
                _statRow('Failed', Text('${sync.failedCount}')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: (!sync.isOnline || sync.isSyncing) ? null : () => sync.syncNow(),
            child: Text(sync.isSyncing ? 'Syncing…' : 'Sync now'),
          ),
          if (!sync.isOnline)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Offline. Everything you do is saved on this device and will sync automatically.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          FutureBuilder<(List<OutboxOp>, List<OutboxOp>)>(
            // Re-queried whenever the sync counters change.
            key: ValueKey('${sync.pendingCount}-${sync.failedCount}-${sync.isSyncing}'),
            future: _load(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final (pending, failed) = snapshot.data!;
              if (pending.isEmpty && failed.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'Everything is synced.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (failed.isNotEmpty) ...[
                    Text("Couldn't sync", style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Card(
                      child: Column(
                        children: [for (final op in failed) _opTile(context, op, failed: true)],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: sync.isSyncing ? null : () => sync.retryFailed(),
                      child: const Text('Retry failed items'),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  if (pending.isNotEmpty) ...[
                    Text('Waiting to sync', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Card(
                      child: Column(
                        children: [for (final op in pending) _opTile(context, op, failed: false)],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}