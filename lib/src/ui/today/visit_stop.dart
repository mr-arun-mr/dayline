import 'package:flutter/material.dart';

import '../../model/calendar_date.dart';
import '../../model/occurrence.dart';
import '../../model/place_stats.dart';
import '../../model/rule_description.dart';
import '../day_rail.dart';
import '../event_colors.dart';
import '../theme.dart';

/// One stay on the day's line: where the device was, from when to when.
///
/// The same shape as an event row — clock column, thread, title — but pinned
/// to the thread twice, at the arrival and at the departure, with the stay
/// drawn between them. That is what makes the day read as a journey rather
/// than as a stack of unrelated rows: you left one place to get to the next.
///
/// A stay is never hidden with what was done. It is not a task that was
/// ticked; it already happened, there is nothing to tidy away, and folding it
/// out of sight would hide the only part of the day the app knows for certain.
class VisitStop extends StatelessWidget {
  const VisitStop({
    required this.occurrence,
    required this.now,
    this.linkedAbove = true,
    this.linkedBelow = true,
    this.onOpen,
    super.key,
  });

  final Occurrence occurrence;
  final DateTime now;

  /// Whether the day's thread carries on to the row above or below.
  final bool linkedAbove;
  final bool linkedBelow;

  /// Opens the per-occurrence sheet, which is where a stay can be adopted as
  /// an event of the user's own.
  final VoidCallback? onOpen;

  static String _clock(DateTime time) =>
      formatWallClock(time.hour * 60 + time.minute);

  /// What the row says under the title: that this is somewhere you went, and
  /// which day either end of it belongs to when it is not this one.
  ///
  /// A stay is one thing seen from every day it touches, so the day it began
  /// is as worth saying as the day it ended. The arrival is said first: on a
  /// morning that carried on from last night it is the part of the row a bare
  /// clock time gets wrong.
  static String _visited({
    required CalendarDate date,
    required DateTime? arrived,
    required DateTime? departed,
  }) {
    final from = arrived == null ? null : _elsewhere(date, arrived);
    if (from != null) {
      return 'Visited · arrived ${_clock(arrived!)} $from';
    }
    if (departed == null) return 'Visited · still there';
    final to = _elsewhere(date, departed);
    return to == null ? 'Visited' : 'Visited · left ${_clock(departed)} $to';
  }

  /// "the next day", "the day before", or a date — for an end of the stay that
  /// is not on the day being drawn. Null when it is.
  static String? _elsewhere(CalendarDate date, DateTime time) =>
      switch (date.daysUntil(CalendarDate.fromDateTime(time))) {
        0 => null,
        1 => 'the next day',
        -1 => 'the day before',
        _ => 'on ${formatDayAndMonth(CalendarDate.fromDateTime(time))}',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colour = EventColors.of(occurrence.event.colorValue);
    final visit = occurrence.visit;
    final departed = visit?.departedAt;

    final clock = theme.textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant)
        .merge(monospacedFigures);

    final Duration? length;
    if (visit != null) {
      length = visit.durationAt(now);
    } else if (occurrence.event.durationMin case final minutes?) {
      length = Duration(minutes: minutes);
    } else {
      length = null;
    }

    // A time with no date on it reads as this day's. A stay that began last
    // night, or that ran past midnight, leaves a bare "19:41" or "00:20" in
    // the column saying the wrong thing, so those are the ones spelled out.
    final line = _visited(
      date: occurrence.date,
      arrived: visit?.arrivedAt,
      departed: departed,
    );

    return InkWell(
      // Somewhere you went is not a checkbox, so a tap opens it rather than
      // ticking it off. There is nothing to tick.
      onTap: onOpen,
      onLongPress: onOpen,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: DaylineTheme.rowMinHeight),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: DaylineTheme.gutter),
              // Two clock times, one against each dot: when you got there and
              // when you left. Read down the day they are its comings and
              // goings, in order.
              SizedBox(
                width: DaylineTheme.timeColumnWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        visit == null
                            ? formatWallClock(occurrence.effectiveTimeOfDay)
                            : _clock(visit.arrivedAt),
                        style: clock,
                      ),
                      Text(
                        // Still inside the fence, so there is no end to put
                        // against the ring: the stay runs up to now.
                        departed == null ? 'now' : _clock(departed),
                        style: clock?.copyWith(
                          color: departed == null
                              ? scheme.outline
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: DaylineTheme.railGap),
              DayRail.span(
                colour: colour,
                isOpen: departed == null,
                linkedAbove: linkedAbove,
                linkedBelow: linkedBelow,
                topInset: 15,
                bottomInset: 15,
              ),
              const SizedBox(width: DaylineTheme.railGap),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        occurrence.event.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        // Why this row is here at all, for one the user did
                        // not write — and, for a stay that crossed midnight,
                        // which day that bare clock time belongs to.
                        line,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (length != null && length > Duration.zero) ...[
                const SizedBox(width: 8),
                Center(
                  child: Text(
                    formatDuration(length),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)
                        .merge(monospacedFigures),
                  ),
                ),
              ],
              const SizedBox(width: DaylineTheme.gutter),
            ],
          ),
        ),
      ),
    );
  }
}
