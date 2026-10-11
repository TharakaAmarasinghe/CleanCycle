import 'package:flutter/material.dart';

import '../../data/repositories/report_repository.dart';
import '../../domain/models/waste_report.dart';

/// Where a report was made: place name plus coordinates once the name
/// resolves, coordinates alone until then. Renders immediately and never
/// waits on the network.
class ReportLocationText extends StatefulWidget {
  final WasteReport report;
  final TextStyle? style;

  const ReportLocationText({super.key, required this.report, this.style});

  @override
  State<ReportLocationText> createState() => _ReportLocationTextState();
}

class _ReportLocationTextState extends State<ReportLocationText> {
  final ReportRepository _repo = ReportRepository();
  late Future<String?> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.placeNameFor(widget.report);
  }

  @override
  void didUpdateWidget(covariant ReportLocationText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report.id != widget.report.id) {
      _future = _repo.placeNameFor(widget.report);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    if (r.latitude == null || r.longitude == null) {
      return Text('No location recorded', style: widget.style);
    }
    final coords = '${r.latitude!.toStringAsFixed(4)}, ${r.longitude!.toStringAsFixed(4)}';
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snapshot) {
        final name = snapshot.data ?? r.placeName;
        return Text(name != null ? '$name ($coords)' : coords, style: widget.style);
      },
    );
  }
}