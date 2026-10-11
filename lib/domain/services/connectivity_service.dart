import 'package:connectivity_plus/connectivity_plus.dart';

/// Wraps connectivity_plus into a simple online/offline stream. Sync is
/// triggered by this stream transitioning to "online" — never polled on
/// a timer, per the constrained-design requirement (unnecessary polling
/// wastes battery for no benefit).
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onlineStatusStream =>
      _connectivity.onConnectivityChanged.map(_isOnline);

  Future<bool> isCurrentlyOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  bool _isOnline(List<ConnectivityResult> results) {
    // connectivity_plus can report multiple simultaneous connections
    // (e.g. wifi + mobile); any non-"none" entry counts as online. Note
    // this confirms a network interface is UP, not that it can actually
    // reach the internet — a captive portal would still read as "online"
    // here. Good enough for triggering a sync attempt, since the sync
    // itself will simply fail and retry if there's no real connectivity.
    return results.any((r) => r != ConnectivityResult.none);
  }
}