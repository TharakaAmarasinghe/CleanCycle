import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../state/auth_state.dart';
import '../../state/bag_state.dart';
import '../../state/sync_state.dart';
import '../../widgets/impact_ring.dart';
import '../../widgets/sync_status_banner.dart';
import '../bag/bag_detail_screen.dart';
import '../bag/create_bag_screen.dart';
import '../sync/sync_centre_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  /// Local first (instant), then push anything waiting, then pull what
  /// collectors recorded, then re-read so the screen catches up.
  Future<void> _refresh() async {
    final user = context.read<AuthState>().currentUser;
    if (user == null) return;
    final bagState = context.read<BagState>();
    final sync = context.read<SyncState>();

    await bagState.refresh(user.id);
    await sync.triggerSync();
    await sync.pullCustodyEvents(bagState.bags.map((b) => b.id).toList());
    if (!mounted) return;
    await bagState.refresh(user.id);
  }

  Widget _header(BuildContext context, BagState bagState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text('Environmental impact', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.lg),
              ImpactRing(
                weightByCategory: bagState.recycledKg,
                totalKg: bagState.totalRecycledKg,
                onSegmentTap: (c) => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${c.label}: ${(bagState.recycledKg[c] ?? 0).toStringAsFixed(1)} kg recycled',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Counts bags a collector has delivered, using your estimated weights.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Your bags', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final bagState = context.watch<BagState>();
    final bags = bagState.bags;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, ${auth.currentUser?.name ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync centre',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SyncCentreScreen()),
            ),
          ),
          // IconButton(icon: const Icon(Icons.logout), onPressed: () => auth.signOut()),
        ],
      ),
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: 1 + (bags.isEmpty ? 1 : bags.length),
                itemBuilder: (context, i) {
                  if (i == 0) return _header(context, bagState);
                  if (bags.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        bagState.isLoading
                            ? 'Loading…'
                            : 'No bags yet. Create your first one with the + button.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }
                  final bag = bags[i - 1];
                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BagDetailScreen(bag: bag)),
                      ),
                      title: Text(
                        '${bag.weightKg.toStringAsFixed(1)} kg · ${bag.categories.map((c) => c.label).join(', ')}',
                      ),
                      subtitle: Text(bag.synced ? 'Synced' : 'Pending sync'),
                      trailing: Icon(
                        bag.synced ? Icons.check_circle : Icons.cloud_off,
                        color: bag.synced ? AppColors.success : AppColors.accentAmber,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateBagScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}