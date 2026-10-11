import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../domain/services/geocoding_service.dart';
import '../../../domain/services/location_service.dart';
import '../../state/auth_state.dart';
import '../../state/report_state.dart';
import '../../state/sync_state.dart';
import '../../widgets/waste_category_picker.dart';

class ReportWasteScreen extends StatefulWidget {
  const ReportWasteScreen({super.key});

  @override
  State<ReportWasteScreen> createState() => _ReportWasteScreenState();
}

class _ReportWasteScreenState extends State<ReportWasteScreen> {
  Set<WasteCategory> _category = {WasteCategory.illegalDumping};
  final _descController = TextEditingController();
  final _picker = ImagePicker();
  final _location = LocationService();
  final _geocoding = GeocodingService();

  String? _photoPath;
  LocationResult? _loc;
  String? _placeName;
  bool _locating = true;
  bool _saving = false;
  late Future<void> _locationFuture;

  @override
  void initState() {
    super.initState();
    _locationFuture = _captureLocation();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  /// One-shot fix when the screen opens: the person is standing at the
  /// waste when they report it. Never a stream.
  Future<void> _captureLocation() async {
    setState(() => _locating = true);
    final loc = await _location.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _loc = loc;
      _locating = false;
    });
    if (loc != null) {
      final name = await _geocoding.placeName(loc.latitude, loc.longitude);
      if (!mounted) return;
      setState(() => _placeName = name);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      // Compressed at capture: smaller to store, to queue and to upload.
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 60,
      );
      if (file == null) return;
      setState(() => _photoPath = file.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Could not open the camera. Try choosing a photo instead.'
                : 'Could not open the gallery.',
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick what you are reporting')),
      );
      return;
    }
    setState(() => _saving = true);

    final user = context.read<AuthState>().currentUser!;
    final reportState = context.read<ReportState>();
    final sync = context.read<SyncState>();
    final messenger = ScaffoldMessenger.of(context);
    final description = _descController.text.trim();

    // If the location fix is still in flight, wait for it (bounded by the
    // service's own 10 s timeout) rather than saving without it.
    await _locationFuture;

    // A local write plus an outbox entry. Nothing here waits on the network.
    await reportState.createReport(
      ownerId: user.id,
      category: _category.first,
      description: description.isEmpty ? null : description,
      latitude: _loc?.latitude,
      longitude: _loc?.longitude,
      placeName: _placeName,
      photoSourcePath: _photoPath,
    );

    sync.triggerSync();
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Report saved on this device. It will sync when online.')),
    );
  }

  Widget _locationRow() {
    final IconData icon;
    final Color color;
    final String text;

    if (_locating) {
      icon = Icons.my_location;
      color = AppColors.textSecondary;
      text = 'Finding your location…';
    } else if (_loc == null) {
      icon = Icons.location_off;
      color = AppColors.accentAmber;
      text = 'Location unavailable. The report will be saved without it.';
    } else {
      icon = Icons.location_on;
      color = AppColors.success;
      final coords = '${_loc!.latitude.toStringAsFixed(4)}, ${_loc!.longitude.toStringAsFixed(4)}';
      text = _placeName != null ? '$_placeName ($coords)' : coords;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text)),
          if (!_locating && _loc == null)
            TextButton(
              onPressed: () => setState(() => _locationFuture = _captureLocation()),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _photoSection() {
    final path = _photoPath;
    if (path != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            child: Image.file(File(path), height: 200, width: double.infinity, fit: BoxFit.cover),
          ),
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: IconButton.filled(
              tooltip: 'Remove photo',
              onPressed: () => setState(() => _photoPath = null),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickPhoto(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Take photo'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickPhoto(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge;

    return Scaffold(
      appBar: AppBar(title: const Text('Report waste')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('What are you reporting?', style: labelStyle),
              const SizedBox(height: AppSpacing.sm),
              // Same component as Create Bag, used single-select here.
              WasteCategoryPicker(
                categories: reportCategories,
                selected: _category,
                maxSelection: 1,
                onChanged: (s) => setState(() => _category = s),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Photo (recommended)', style: labelStyle),
              const SizedBox(height: AppSpacing.sm),
              _photoSection(),
              const SizedBox(height: AppSpacing.xxl),
              Text('Location', style: labelStyle),
              const SizedBox(height: AppSpacing.sm),
              _locationRow(),
              const SizedBox(height: AppSpacing.xxl),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Add more details about the waste',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "Works offline: the report is saved on this device and sent when you're back online.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text('Save report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}