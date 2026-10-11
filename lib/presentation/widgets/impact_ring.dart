import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

/// Custom component: a segmented ring showing recycled weight by
/// category, drawn directly on a Canvas with a CustomPainter.
///
/// Properties
///   weightByCategory   kg per category; zero or missing entries are skipped
///   totalKg            the figure shown in the centre
///   animationDuration  how long the ring takes to sweep in
///   size               width and height of the ring
///   strokeWidth        thickness of the ring
/// Events
///   onSegmentTap       a ring segment or legend row was tapped
///
/// The ring sweeps in from zero whenever the data changes (the animation
/// is keyed on the data). Informational only: no targets, badges or streaks.
class ImpactRing extends StatelessWidget {
  final Map<WasteCategory, double> weightByCategory;
  final double totalKg;
  final Duration animationDuration;
  final double size;
  final double strokeWidth;
  final ValueChanged<WasteCategory>? onSegmentTap;

  const ImpactRing({
    super.key,
    required this.weightByCategory,
    required this.totalKg,
    this.animationDuration = const Duration(milliseconds: 900),
    this.size = 160,
    this.strokeWidth = 18,
    this.onSegmentTap,
  });

  Color _colorFor(WasteCategory c) => switch (c) {
    WasteCategory.plastic => AppColors.categoryPlastic,
    WasteCategory.glass => AppColors.categoryGlass,
    WasteCategory.paper => AppColors.categoryPaper,
    WasteCategory.metal => AppColors.categoryMetal,
    _ => AppColors.textSecondary,
  };

  /// Turns weights into arcs. `offset` is how far round the ring the
  /// segment starts (radians, clockwise from 12 o'clock); `sweep` is its length.
  List<_Segment> _buildSegments() {
    final entries = weightByCategory.entries.where((e) => e.value > 0).toList();
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);
    if (total <= 0) return const [];

    var offset = 0.0;
    final result = <_Segment>[];
    for (final e in entries) {
      final sweep = e.value / total * 2 * math.pi;
      result.add(_Segment(e.key, offset, sweep, _colorFor(e.key)));
      offset += sweep;
    }
    return result;
  }

  /// Converts a tap position to an angle and finds which segment it hit.
  void _handleTap(Offset p, List<_Segment> segments) {
    final center = Offset(size / 2, size / 2);
    final dx = p.dx - center.dx;
    final dy = p.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    // Only taps on the ring itself count (with a little slack either side).
    final outer = size / 2 + 6;
    final inner = size / 2 - strokeWidth - 6;
    if (distance > outer || distance < inner) return;

    // atan2 gives 0 at 3 o'clock; shift so 0 is 12 o'clock, clockwise.
    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    for (final s in segments) {
      if (angle >= s.offset && angle < s.offset + s.sweep) {
        onSegmentTap?.call(s.category);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final segments = _buildSegments();
    final signature =
    segments.map((s) => '${s.category.name}:${s.sweep.toStringAsFixed(3)}').join('|');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _handleTap(d.localPosition, segments),
          child: SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              // New key = new animation: the ring re-sweeps when data changes.
              key: ValueKey(signature),
              tween: Tween<double>(begin: 0, end: 1),
              duration: animationDuration,
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.square(size),
                    painter: _RingPainter(
                      segments: segments,
                      progress: t,
                      strokeWidth: strokeWidth,
                      signature: signature,
                    ),
                  ),
                  child!,
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${totalKg.toStringAsFixed(1)} kg',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text('Total recycled', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (segments.isEmpty)
          Text('Nothing delivered yet', style: Theme.of(context).textTheme.bodyMedium)
        else
          for (final s in segments) _legendRow(s),
      ],
    );
  }

  Widget _legendRow(_Segment s) {
    final kg = weightByCategory[s.category] ?? 0;
    return InkWell(
      onTap: onSegmentTap == null ? null : () => onSegmentTap!(s.category),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinTouchTarget),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(s.category.label)),
            Text('${kg.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Segment {
  final WasteCategory category;
  final double offset;
  final double sweep;
  final Color color;
  const _Segment(this.category, this.offset, this.sweep, this.color);
}

class _RingPainter extends CustomPainter {
  final List<_Segment> segments;
  final double progress; // 0..1: how much of the full circle is revealed
  final double strokeWidth;
  final String signature;

  _RingPainter({
    required this.segments,
    required this.progress,
    required this.strokeWidth,
    required this.signature,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Stroke is drawn centred on the path, so inset by half its width.
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Grey track underneath, so an empty ring is still visible.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = AppColors.border,
    );

    // Canvas angles start at 3 o'clock; -pi/2 moves the start to 12.
    const startAngle = -math.pi / 2;
    final revealed = progress * 2 * math.pi;

    for (final s in segments) {
      final visible = (revealed - s.offset).clamp(0.0, s.sweep).toDouble();
      if (visible <= 0) continue;
      canvas.drawArc(
        rect,
        startAngle + s.offset,
        visible,
        false, // false = draw the arc only, not a pie wedge
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt
          ..color = s.color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.signature != signature || old.strokeWidth != strokeWidth;
}