import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final double accuracyMeters;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });
}

/// One-shot location fix, requested at the moment it's needed (when a
/// collector confirms a scan) — never a continuous stream. A stream
/// would keep the GPS radio awake the whole session for no benefit,
/// which is exactly the battery waste the constrained-design criterion
/// is about.
///
/// Returns null (never throws) when location is unavailable — services
/// off, permission denied, or no fix within the timeout. The caller
/// records the custody event anyway, just without coordinates: a
/// refused permission must never block the core workflow.
///
/// Every null path logs its reason, so "location unavailable" is
/// diagnosable instead of a mystery.
class LocationService {
  Future<LocationResult?> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('LocationService: device location services are OFF');
      return null;
    }

    var permission = await Geolocator.checkPermission();
    debugPrint('LocationService: permission is $permission');
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('LocationService: after request, permission is $permission');
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('LocationService: permission refused, giving up');
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      debugPrint(
        'LocationService: fix ${position.latitude}, ${position.longitude} '
            '(±${position.accuracy} m)',
      );
      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } catch (e) {
      // Timeout or platform error — degrade gracefully rather than fail.
      debugPrint('LocationService: position request failed: $e');
      return null;
    }
  }
}