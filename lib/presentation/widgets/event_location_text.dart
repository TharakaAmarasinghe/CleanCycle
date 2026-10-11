import 'package:flutter/material.dart';

import '../../data/repositories/bag_repository.dart';
import '../../domain/models/custody_event.dart';

/// Shows where a custody event happened: place name plus coordinates once
/// the name resolves, coordinates alone until then (or if it never does).
/// Renders immediately — it never waits on the network to show something.
class EventLocationText extends StatefulWidget {
  final CustodyEvent event;
  final TextStyle? style;

  const EventLocationText({super.key, required this.event, this.style});

  @override
  State<EventLocationText> createState() => _EventLocationTextState();
}

class _EventLocationTextState extends State<EventLocationText> {
  final BagRepository _repo = BagRepository();
  late Future<String?> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.placeNameFor(widget.event);
  }

  @override
  void didUpdateWidget(covariant EventLocationText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id) {
      _future = _repo.placeNameFor(widget.event);
    }
  }

  String _coords(CustodyEvent e) =>
      '${e.latitude!.toStringAsFixed(4)}, ${e.longitude!.toStringAsFixed(4)}';

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    if (e.latitude == null || e.longitude == null) {
      return Text('No location recorded', style: widget.style);
    }
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snapshot) {
        final name = snapshot.data;
        return Text(
          name != null ? '$name (${_coords(e)})' : _coords(e),
          style: widget.style,
        );
      },
    );
  }
}