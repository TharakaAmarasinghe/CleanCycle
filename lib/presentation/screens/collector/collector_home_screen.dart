import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../../state/auth_state.dart';
import '../../widgets/sync_status_banner.dart';
import 'scanner_screen.dart';
import '../sync/sync_centre_screen.dart';

class CollectorHomeScreen extends StatelessWidget {
  const CollectorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

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
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(72)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScannerScreen()),
                  ),
                  icon: const Icon(Icons.qr_code_scanner, size: 28),
                  label: const Text('Scan QR'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}