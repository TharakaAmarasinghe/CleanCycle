import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Turns coordinates into a short human-readable place name using
/// OpenStreetMap's Nominatim service. Best-effort and online-only: it
/// returns null on any failure (offline, timeout, no result) and the UI
/// falls back to showing coordinates.
///
/// Never call this on the write path — it needs the network, and the
/// whole point of the app is that recording an event doesn't.
///
/// Nominatim's usage policy asks for an identifying User-Agent and at
/// most one request per second. Results are cached in memory here and
/// persisted per event in SQLite, so each location is looked up once.
/// Fine at this scale; a production app would use a paid or self-hosted
/// geocoder. Place names © OpenStreetMap contributors.
class GeocodingService {
  static final Map<String, String> _cache = {};

  Future<String?> placeName(double latitude, double longitude) async {
    // ~11 m precision: nearby points share one cache entry.
    final key = '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    final cached = _cache[key];
    if (cached != null) return cached;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'zoom': '16',
        'addressdetails': '1',
      });
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 6));
      request.headers.set(HttpHeaders.userAgentHeader, 'CleanCycle/1.0 (SE5070 student project)');
      request.headers.set(HttpHeaders.acceptLanguageHeader, 'en');
      final response = await request.close().timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        debugPrint('GeocodingService: HTTP ${response.statusCode}');
        await response.drain<void>();
        return null;
      }

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 6));
      final json = jsonDecode(body) as Map<String, dynamic>;
      final name = _format(json['address'] as Map<String, dynamic>?);
      if (name != null) _cache[key] = name;
      return name;
    } catch (e) {
      debugPrint('GeocodingService: lookup failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// "Fort, Colombo" style: neighbourhood + city. Deliberately stops short
  /// of street level — enough to be recognisable, and no more of a
  /// household's exact address than the coordinates already carry.
  String? _format(Map<String, dynamic>? address) {
    if (address == null) return null;

    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = address[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    final area = pick(['suburb', 'neighbourhood', 'quarter', 'village', 'hamlet']);
    final city = pick(['city', 'town', 'municipality', 'city_district', 'county', 'state_district']);

    final parts = <String>[
      ?area,
      if (city != null && city != area) city,
    ];

    if (parts.isEmpty) {
      final state = pick(['state', 'province', 'region']);
      if (state != null) parts.add(state);
    }
    return parts.isEmpty ? null : parts.join(', ');
  }
}