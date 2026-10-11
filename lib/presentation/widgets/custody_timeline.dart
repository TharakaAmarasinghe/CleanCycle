import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../domain/models/custody_event.dart';
import 'event_location_text.dart';

/// Custom component: a bag's custody journey as a vertical timeline,
/// built from the event history rather than a single status field.
///
/// Properties
///   createdAt     when the bag was created (the first stage)
///   events        the bag's custody events, in any order
///   showLocation  show place name and coordinates under each event
/// Events
///   onEventTap    a stage that has an event was tapped
///
/// Completed stages are filled, pending ones hollow. The last stage is a
/// placeholder for facility confirmation, which this version doesn't do.
class CustodyTimeline extends StatelessWidget {
  final DateTime createdAt;
  final List<CustodyEvent> events;
  final bool showLocation;
  final ValueChanged<CustodyEvent>? onEventTap;

  const CustodyTimeline({
    super.key,
    required this.createdAt,
    required this.events,
    this.showLocation = true,
    this.onEventTap,
  });

  String _fmt(DateTime d) => DateFormat('d MMM, HH:mm').format(d);

  @override
  Widget build(BuildContext context) {
    // Earliest event of each type wins, whatever order they arrived in.
    final sorted = [...events]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    CustodyEvent? first(CustodyEventType t) {
      for (final e in sorted) {
        if (e.type == t) return e;
      }
      return null;
    }

    final collected = first(CustodyEventType.collected);
    final delivered = first(CustodyEventType.delivered);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stage(context, label: 'Bag created', done: true, time: _fmt(createdAt)),
        _stage(
          context,
          label: 'Collected',
          done: collected != null,
          time: collected == null ? null : _fmt(collected.occurredAt),
          event: collected,
        ),
        _stage(
          context,
          label: 'Delivered',
          done: delivered != null,
          time: delivered == null ? null : _fmt(delivered.occurredAt),
          event: delivered,
        ),
        _stage(
          context,
          label: 'Verified',
          done: false,
          time: 'Planned: facility confirmation',
          isLast: true,
        ),
      ],
    );
  }

  Widget _stage(
      BuildContext context, {
        required String label,
        required bool done,
        String? time,
        CustodyEvent? event,
        bool isLast = false,
      }) {
    final secondary = Theme.of(context).textTheme.bodyMedium;
    final tappable = event != null && onEventTap != null;

    return InkWell(
      onTap: tappable ? () => onEventTap!(event) : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? AppColors.primaryGreen : AppColors.surface,
                    border: done ? null : Border.all(color: AppColors.border, width: 2),
                  ),
                  child: done ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
                ),
                if (!isLast) Expanded(child: Container(width: 1.5, color: AppColors.border)),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: done ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                        if (tappable)
                          const Padding(
                            padding: EdgeInsets.only(left: AppSpacing.xs),
                            child: Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                    if (time != null && time.isNotEmpty) Text(time, style: secondary),
                    if (showLocation && event != null) EventLocationText(event: event, style: secondary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}