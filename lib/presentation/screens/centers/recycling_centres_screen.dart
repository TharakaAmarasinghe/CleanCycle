import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../data/sample_centres.dart';
import '../../../domain/models/recycling_centre.dart';
import '../../../domain/services/location_service.dart';
import '../../../domain/services/maps_launcher.dart';

class _Entry {
  final RecyclingCentre centre;
  final double? km;
  const _Entry(this.centre, this.km);
}

class RecyclingCentresScreen extends StatefulWidget {
  const RecyclingCentresScreen({super.key});

  @override
  State<RecyclingCentresScreen> createState() => _RecyclingCentresScreenState();
}

class _RecyclingCentresScreenState extends State<RecyclingCentresScreen> {
  final LocationService _location = LocationService();
  final MapsLauncher _maps = MapsLauncher();

  LocationResult? _loc;
  bool _locating = true;
  WasteCategory? _filter; // null = all materials

  @override
  void initState() {
    super.initState();
    _locate();
  }

  /// One-shot fix, taken when the tab is first opened. Never a stream.
  Future<void> _locate() async {
    final loc = await _location.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _loc = loc;
      _locating = false;
    });
  }

  List<_Entry> _entries() {
    final loc = _loc;
    final list = sampleCentres
        .where((c) => _filter == null || c.accepts.contains(_filter))
        .map((c) {
      final km = loc == null
          ? null
          : Geolocator.distanceBetween(
        loc.latitude,
        loc.longitude,
        c.latitude,
        c.longitude,
      ) /
          1000;
      return _Entry(c, km);
    }).toList();
    if (loc != null) list.sort((a, b) => a.km!.compareTo(b.km!));
    return list;
  }

  String _distanceLabel(double km) =>
      km < 1 ? '${(km * 1000).round()} m away' : '${km.toStringAsFixed(1)} km away';

  Future<void> _directions(RecyclingCentre c) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await _maps.openDirections(
      latitude: c.latitude,
      longitude: c.longitude,
    );
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open a maps app on this device.")),
      );
    }
  }

  Widget _infoNote() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Sample data for demonstration. A real deployment would load a verified '
                  'directory. Distances are straight-line from your current location.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationStatus() {
    if (_locating) {
      return Text('Finding your location…', style: Theme.of(context).textTheme.bodyMedium);
    }
    if (_loc != null) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.location_off, size: 18, color: AppColors.accentAmber),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Location unavailable. Showing centres without distances.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        TextButton(
          onPressed: () {
            setState(() => _locating = true);
            _locate();
          },
          child: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _filters() {
    final options = <WasteCategory?>[null, ...bagCategories];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final c in options)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(c?.label ?? 'All'),
                selected: _filter == c,
                selectedColor: AppColors.lightGreen,
                onSelected: (_) => setState(() => _filter = c),
              ),
            ),
        ],
      ),
    );
  }

  Widget _materialChip(WasteCategory m) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        m.label,
        style: const TextStyle(
          color: AppColors.primaryGreen,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _card(_Entry e) {
    final c = e.centre;
    final secondary = Theme.of(context).textTheme.bodyMedium;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(c.area, style: secondary),
            if (e.km != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  _distanceLabel(e.km!),
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [for (final m in c.accepts) _materialChip(m)],
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => _directions(c),
              icon: const Icon(Icons.directions),
              label: const Text('Get directions'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Center(child: Text('Opens your maps app', style: secondary)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();

    return Scaffold(
      appBar: AppBar(title: const Text('Recycling centres')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _infoNote(),
          const SizedBox(height: AppSpacing.md),
          _locationStatus(),
          const SizedBox(height: AppSpacing.sm),
          _filters(),
          const SizedBox(height: AppSpacing.md),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'No centres in the sample data accept ${_filter?.label ?? 'this'}.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            for (final e in entries) _card(e),
        ],
      ),
    );
  }
}