import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/calendar_date.dart';
import '../../model/holiday.dart';
import '../../providers.dart';
import '../holidays/holidays_screen.dart';
import '../theme.dart';

/// Says why the day is quieter than usual.
///
/// Without this a holiday looks exactly like a bug: the school run is simply
/// missing, with nothing on screen to say the app did that on purpose. Naming
/// the holiday and what it closed is the difference between a feature and a
/// disappearance.
class HolidayBanner extends ConsumerWidget {
  const HolidayBanner({required this.date, super.key});

  final CalendarDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(holidaysProvider).value ?? const <Holiday>[];
    final today = holidaysOn(all, date);
    if (today.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final closed = scopesClosedOn(today, date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        10,
        DaylineTheme.gutter,
        2,
      ),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => HolidaysScreen.open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.beach_access,
                  size: 20,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        // More than one holiday can land on a day — a bank
                        // holiday inside a week of leave — and both named is
                        // more use than one of them picked arbitrarily.
                        today.map((h) => h.name).join(' · '),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        describeClosed(closed),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Work and school events are paused", or the honest nothing-happened case.
String describeClosed(Set<HolidayScope> closed) {
  if (closed.isEmpty) return 'Nothing is paused';
  final names = [
    for (final scope in HolidayScope.values)
      if (closed.contains(scope)) describeScope(scope).toLowerCase(),
  ];
  return '${_sentenceCase(names.join(' and '))} events are paused';
}

String _sentenceCase(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
