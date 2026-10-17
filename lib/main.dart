import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, Settings;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'presentation/screens/auth/sign_in_screen.dart';
import 'presentation/screens/collector/collector_home_screen.dart';
import 'presentation/screens/household/household_shell.dart';
import 'presentation/state/auth_state.dart';
import 'presentation/state/bag_state.dart';
import 'presentation/state/report_state.dart';
import 'presentation/state/sync_state.dart';
import 'presentation/state/collector_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firestore's built-in offline cache is switched OFF on purpose. The
  // app's offline behaviour is the SQLite + outbox design; leaving the
  // SDK's cache on would let it quietly do the job instead.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);

  runApp(const CleanCycleApp());
}

class CleanCycleApp extends StatelessWidget {
  const CleanCycleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => BagState()),
        ChangeNotifierProvider(create: (_) => ReportState()),
        ChangeNotifierProvider(create: (_) => SyncState()),
        ChangeNotifierProvider(create: (_) => CollectorState()),
      ],
      child: MaterialApp(
        title: 'CleanCycle',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _RootRouter(),
      ),
    );
  }
}

/// Watches auth status and shows the right top-level screen. This is the
/// ONLY place that branches on AuthStatus and role; individual screens
/// never re-check who they are showing to.
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🌱', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                Text('CleanCycle', style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        );
      case AuthStatus.signedOut:
        return const SignInScreen();
      case AuthStatus.signedIn:
        return auth.currentUser?.role == UserRole.collector
            ? const CollectorHomeScreen()
            : const HouseholdShell();
    }
  }
}