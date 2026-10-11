import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands navigation to the device's own maps app. The app embeds no map
/// SDK and does no routing itself. The URL opens Google Maps if it is
/// installed, or the browser otherwise.
class MapsLauncher {
  /// Returns false (never throws) when nothing could open the link.
  Future<bool> openDirections({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
    });
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('MapsLauncher: could not open maps: $e');
      return false;
    }
  }
}