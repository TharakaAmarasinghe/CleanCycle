import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../state/auth_state.dart';
import '../../state/bag_state.dart';
import '../../state/report_state.dart';
import '../../state/sync_state.dart';
import '../sync/sync_centre_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Signing out doesn't delete local data or stop syncing. Queued items
  /// stay in SQLite and go up when the connection allows, so the dialog
  /// says that instead of leaving the person to wonder.
  Future<void> _confirmSignOut(BuildContext context) async {
    final auth = context.read<AuthState>();
    final sync = context.read<SyncState>();
    final waiting = sync.pendingCount + sync.failedCount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(
          waiting > 0
              ? "$waiting item${waiting == 1 ? '' : 's'} haven't synced yet. They are saved on "
              "this device and will sync when you're online."
              : 'You can sign back in at any time.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed == true) await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final bagState = context.watch<BagState>();
    final reportState = context.watch<ReportState>();
    final sync = context.watch<SyncState>();

    final user = auth.currentUser;
    final name = user?.name ?? '';
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final roleLabel = user?.role == UserRole.collector ? 'Collector' : 'Household';
    final waiting = sync.pendingCount + sync.failedCount;
    final secondary = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.lightGreen,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(name, style: Theme.of(context).textTheme.headlineMedium),
              Text(user?.email ?? '', style: secondary),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  roleLabel,
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Sync centre'),
                  subtitle: Text(
                    '${sync.isOnline ? 'Online' : 'Offline'} · '
                        '${waiting == 0 ? 'nothing waiting' : '$waiting waiting'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SyncCentreScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('On this device'),
                  subtitle: Text(
                    '${bagState.bags.length} bags · ${reportState.reports.length} reports. '
                        'Everything is saved here first.',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About CleanCycle'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'CleanCycle',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Text('🌱', style: TextStyle(fontSize: 32)),
                    children: const [
                      Text(
                        'Report. Recycle. Verify.\n\n'
                            'Offline-first: everything is saved on your device first and synced '
                            'when you are online.\n\n'
                            'Place names © OpenStreetMap contributors.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            onPressed: () => _confirmSignOut(context),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}