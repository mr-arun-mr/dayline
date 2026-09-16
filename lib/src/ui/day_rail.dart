import 'package:flutter/material.dart';

import 'theme.dart';

/// The thread the day hangs from.
///
/// One vertical line runs down the whole day, beside the column of clock
/// times, and every row is pinned to it: an event is a single dot, a stay is
/// two — where it began and where it ended — with the line between them drawn
/// in the place's own colour, so a long afternoon somewhere *looks* long.
/// Unconnected rows say nothing about how the day fitted together; this is the
/// connection.
///
/// A marker is filled once the thing it marks has happened and hollow while it
/// has not, which is the same idea in both directions: a plan not got to yet,
/// and a stay not yet left.
class DayRail extends StatelessWidget {
  /// A single point in the day: an event, done or not. Its dot is centred on
  /// the row, where a row's one clock time sits.
  const DayRail.moment({
    required this.colour,
    required this.filled,
    this.linkedAbove = true,
    this.linkedBelow = true,
    super.key,
  })  : isSpan = false,
        isOpen = false,
        topInset = 0,
        bottomInset = 0;

  /// A stretch of the day: a stay, from arrival to departure. Its two dots sit
  /// against the top and bottom of the row, where the two clock times are.
  const DayRail.span({
    required this.colour,
    required this.isOpen,
    this.linkedAbove = true,
    this.linkedBelow = true,
    this.topInset = 6,
    this.bottomInset = 6,
    super.key,
  })  : isSpan = true,
        filled = true;

  /// The event's or the place's colour.
  final Color colour;

  /// Whether the marker is filled in — a moment that has happened.
  final bool filled;

  final bool isSpan;

  /// A stay with no end yet: the closing ring is drawn as an end that has not
  /// happened.
  final bool isOpen;

  /// Whether the thread continues to the row above or below. False at the two
  /// ends of the day, where a line running off into nothing would imply more.
  final bool linkedAbove;
  final bool linkedBelow;

  /// How far down the row a span's first dot sits, and how far up from the
  /// bottom its last — enough to line them up with the text beside them.
  final double topInset;
  final double bottomInset;

  static const _dot = DaylineTheme.railWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thread = scheme.outlineVariant;
    final above = linkedAbove ? thread : Colors.transparent;
    final below = linkedBelow ? thread : Colors.transparent;

    return SizedBox(
      width: DaylineTheme.railWidth,
      child: Column(
        children: isSpan
            ? [
                _Thread(colour: above, height: topInset),
                _Dot(colour: colour, filled: true),
                // The stay itself, at its own length.
                Expanded(
                  child: _Thread(colour: colour.withValues(alpha: 0.45)),
                ),
                _Dot(colour: isOpen ? scheme.outline : colour, filled: false),
                _Thread(colour: below, height: bottomInset),
              ]
            : [
                Expanded(child: _Thread(colour: above)),
                _Dot(colour: colour, filled: filled),
                Expanded(child: _Thread(colour: below)),
              ],
      ),
    );
  }
}

class _Thread extends StatelessWidget {
  const _Thread({required this.colour, this.height});

  final Color colour;
  final double? height;

  @override
  Widget build(BuildContext context) =>
      Container(width: 2, height: height, color: colour);
}

class _Dot extends StatelessWidget {
  const _Dot({required this.colour, required this.filled});

  final Color colour;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    width: DayRail._dot,
    height: DayRail._dot,
    decoration: BoxDecoration(
      color: filled ? colour : Theme.of(context).colorScheme.surface,
      shape: BoxShape.circle,
      border: Border.all(color: colour, width: 2),
    ),
  );
}
