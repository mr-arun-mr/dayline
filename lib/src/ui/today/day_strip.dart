import 'package:flutter/material.dart';

import '../../model/calendar_date.dart';
import '../theme.dart';

/// The horizontal date scrubber under the header.
///
/// Scrolls a wide range rather than exactly seven days: seven fit on screen,
/// but the user can push back a week or forward a couple of months without
/// the strip feeling like a wall.
class DayStrip extends StatefulWidget {
  const DayStrip({
    required this.today,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final CalendarDate today;
  final CalendarDate selected;
  final ValueChanged<CalendarDate> onSelected;

  /// How far either side of today the strip reaches.
  static const daysBefore = 14;
  static const daysAfter = 120;

  static const _itemExtent = 54.0;
  static const _height = 78.0;

  @override
  State<DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<DayStrip> {
  late final ScrollController _controller = ScrollController();

  int _indexOf(CalendarDate date) =>
      widget.today.daysUntil(date) + DayStrip.daysBefore;

  CalendarDate _dateAt(int index) =>
      widget.today.addDays(index - DayStrip.daysBefore);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centre(animate: false));
  }

  @override
  void didUpdateWidget(DayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _centre();
  }

  /// Puts the selected day in the middle of the viewport, clamped to the ends
  /// so the strip never scrolls into empty space.
  void _centre({bool animate = true}) {
    if (!_controller.hasClients) return;
    final viewport = _controller.position.viewportDimension;
    final target = (_indexOf(widget.selected) * DayStrip._itemExtent) -
        (viewport / 2) +
        (DayStrip._itemExtent / 2);
    final clamped = target.clamp(
      _controller.position.minScrollExtent,
      _controller.position.maxScrollExtent,
    );
    if (animate) {
      _controller.animateTo(
        clamped,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _controller.jumpTo(clamped);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: DayStrip._height,
      child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemExtent: DayStrip._itemExtent,
        padding: const EdgeInsets.symmetric(
          horizontal: DaylineTheme.gutter - 8,
        ),
        itemCount: DayStrip.daysBefore + DayStrip.daysAfter + 1,
        itemBuilder: (context, index) {
          final date = _dateAt(index);
          return _DayCell(
            date: date,
            isSelected: date == widget.selected,
            isToday: date == widget.today,
            onTap: () => widget.onSelected(date),
          );
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final CalendarDate date;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  static const _initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isWeekend = date.weekday >= DateTime.saturday;

    final Color background;
    final Color foreground;
    if (isSelected) {
      background = scheme.onSurface;
      foreground = scheme.surface;
    } else {
      background = Colors.transparent;
      foreground = isWeekend ? scheme.onSurfaceVariant : scheme.onSurface;
    }

    return Semantics(
      selected: isSelected,
      button: true,
      label: '${date.day} ${date.month} ${date.year}'
          '${isToday ? ', today' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _initials[date.weekday - 1],
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                border: isToday && !isSelected
                    ? Border.all(color: scheme.primary, width: 1.5)
                    : null,
              ),
              child: Text(
                '${date.day}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: foreground,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w500,
                ).merge(monospacedFigures),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
