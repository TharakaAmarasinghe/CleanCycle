import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme.dart';
import '../../../data/repositories/bag_repository.dart';
import '../../widgets/sync_status_banner.dart';
import 'scan_confirmation_screen.dart';

/// A bag tag encodes only the bag's UUID. Anything else (a random QR
/// code, a URL) is rejected before it can become a custody event.
final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  final TextEditingController _codeController = TextEditingController();
  final BagRepository _repo = BagRepository();
  bool _navigating = false;

  @override
  void dispose() {
    _controller.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openConfirmation(String bagId) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await _controller.stop();
    } catch (_) {
      // Camera may never have started (e.g. emulator) — nothing to stop.
    }
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScanConfirmationScreen(bagId: bagId)),
    );

    // Only reached if the user came BACK here (e.g. pressed back on the
    // confirmation screen). After a recorded event the whole stack is
    // popped and this screen is disposed, so mounted is false.
    if (!mounted) return;
    _navigating = false;
    try {
      await _controller.start();
    } catch (_) {}
  }

  void _onDetect(BarcodeCapture capture) {
    if (_navigating) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;

    if (!_uuidPattern.hasMatch(raw)) {
      _showMessage('That QR code is not a CleanCycle bag tag.');
      return;
    }
    _openConfirmation(raw.toLowerCase());
  }

  Future<void> _submitManualCode() async {
    FocusScope.of(context).unfocus();
    final code = _codeController.text.trim();

    if (_uuidPattern.hasMatch(code)) {
      _openConfirmation(code.toLowerCase());
      return;
    }
    if (code.length < 4) {
      _showMessage('Enter at least 4 characters of the code shown with the bag.');
      return;
    }

    final bag = await _repo.findBagByCode(code);
    if (!mounted) return;
    if (bag == null) {
      _showMessage('No bag with that code on this device. Scan the QR tag instead.');
      return;
    }
    _openConfirmation(bag.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan bag tag')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SyncStatusBanner(),
              Container(
                height: 300,
                margin: const EdgeInsets.all(AppSpacing.lg),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (context, error, child) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            'Camera unavailable on this device.\nUse manual entry below.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 3),
                            borderRadius: BorderRadius.circular(AppRadius.medium),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Point the camera at the QR tag',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Can't scan? Enter the bag code",
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Bag code',
                        hintText: 'e.g. A4F2',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Stacked under the field rather than beside it: the
                    // theme's buttons are full-width, and a full-width
                    // button inside a Row throws a layout error.
                    OutlinedButton(
                      onPressed: _submitManualCode,
                      child: const Text('Look up code'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}