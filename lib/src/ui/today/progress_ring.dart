import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// "3 of 6 done", as a ring.
///
/// Sized to read at arm's length and drawn with a track behind it, so an empty
/// ring still looks like a ring rather than a missing element.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.progress,
    required this.doneCount,
    required this.expected,
    required this.isComplete,
    super.key,
  });

  final double progress;
  final int doneCount;
  final int expected;
  final bool isComplete;

  static const _size = 52.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(_size),
            painter: _RingPainter(
              progress: progress,
              track: scheme.outlineVariant,
              fill: isComplete ? _completeGreen : scheme.primary,
            ),
          ),
          if (isComplete)
            Icon(Icons.check, size: 24, color: _completeGreen)
          else
            Text(
              '$doneCount/$expected',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700)
                  .merge(monospacedFigures),
            ),
        ],
      ),
    );
  }

  static const _completeGreen = Color(0xFF10B981);
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  final double progress;
  final Color track;
  final Color fill;

  static const _stroke = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (size.shortestSide - _stroke) / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = track;
    canvas.drawCircle(centre, radius, trackPaint);

    if (progress <= 0) return;

    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = fill;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      // Twelve o'clock, clockwise.
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.fill != fill || old.track != track;
}
