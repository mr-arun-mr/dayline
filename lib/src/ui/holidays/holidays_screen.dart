import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/calendar_date.dart';
import '../../model/holiday.dart';
import '../../model/rule_description.dart';
import '../../providers.dart';
import '../theme.dart';
import 'edit_holiday_screen.dart';

/// Days the user has said do not happen, and what each of them closes.
class HolidaysScreen extends ConsumerWidget {
  const HolidaysScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const HolidaysScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holidays = ref.watch(holidaysProvider);
    final today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Holidays')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => EditHolidayScreen.open(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: switch (holidays) {
        AsyncData(:final value) when value.isEmpty => const _Empty(),
        AsyncData(:final value) => _List(holidays: value, today: today),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.holidays, required this.today});

  final List<Holiday> holidays;
  final CalendarDate today;

  @override
  Widget build(BuildContext context) {
    // Over first, soonest of those at the top, then everything still to come.
    // A list of last year's bank holidays above next week's half-term is a
    // list nobody reads.
    final upcoming =
        holidays.where((h) => !h.endDate.isBefore(today)).toList();
    final past = holidays.where((h) => h.endDate.isBefore(today)).toList()
      ..sort((a, b) => b.startDate.epochDay.compareTo(a.startDate.epochDay));

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        if (upcoming.isNotEmpty) ...[
          const _Heading(label: 'Coming up'),
          for (final holiday in upcoming)
            _Row(holiday: holiday, today: today),
        ],
        if (past.isNotEmpty) ...[
          const _Heading(label: 'Been and gone'),
          for (final holiday in past) _Row(holiday: holiday, today: today),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        20,
        DaylineTheme.gutter,
        6,
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.holiday, required this.today});

  final Holiday holiday;
  final CalendarDate today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isOn = holiday.covers(today);

    return Dismissible(
      key: ValueKey('holiday-${holiday.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: DaylineTheme.gutter),
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      onDismissed: (_) =>
          ref.read(holidaysDaoProvider).deleteHoliday(holiday.id),
      child: ListTile(
        minTileHeight: DaylineTheme.rowMinHeight,
        leading: Icon(
          isOn ? Icons.beach_access : Icons.beach_access_outlined,
          color: isOn ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(holiday.name),
        subtitle: Text(
          '${describeHolidayDates(holiday)} · ${describeScopes(holiday.scopes)}',
        ),
        trailing: isOn
            ? Text(
                'Today',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: scheme.primary),
              )
            : null,
        onTap: () => EditHolidayScreen.open(context, holidayId: holiday.id),
      ),
    );
  }
}

/// "12 Aug", or "12–16 Aug" for a run of days.
String describeHolidayDates(Holiday holiday) {
  if (holiday.isSingleDay) return formatMediumDate(holiday.startDate);
  return '${formatMediumDate(holiday.startDate)} – '
      '${formatMediumDate(holiday.endDate)} (${holiday.days} days)';
}

/// "Work and school", "Work", "School", or a holiday that closes nothing.
String describeScopes(int scopes) {
  final closed = HolidayScopes.from(scopes);
  if (closed.isEmpty) return 'Nothing closed';
  return closed.map(describeScope).join(' and ');
}

String describeScope(HolidayScope scope) => switch (scope) {
  HolidayScope.work => 'Work',
  HolidayScope.school => 'School',
};

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.beach_access_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No holidays yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a bank holiday, a week off or half-term, and anything you '
              'have marked as belonging to work or school steps aside for it.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
