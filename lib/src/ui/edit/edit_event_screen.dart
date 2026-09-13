import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/database.dart';
import '../../model/calendar_date.dart';
import '../../model/place.dart';
import '../../model/recurrence.dart';
import '../../model/rule_description.dart';
import '../../providers.dart';
import '../event_colors.dart';
import '../theme.dart';
import 'delete_scope_sheet.dart';

/// Add or edit one rule.
class EditEventScreen extends ConsumerStatefulWidget {
  const EditEventScreen({
    this.eventId,
    this.initialDate,
    this.occurrenceDate,
    super.key,
  });

  /// Null when creating.
  final int? eventId;

  /// The day the user was looking at when they tapped Add.
  final CalendarDate? initialDate;

  /// The specific day they opened this from, if they came from a row on the
  /// Today screen. It is what "this occurrence" means when deleting; null when
  /// the editor was reached without a day in mind.
  final CalendarDate? occurrenceDate;

  static const supportedRecurrences = Recurrence.values;

  static Future<void> open(
    BuildContext context, {
    int? eventId,
    CalendarDate? initialDate,
    CalendarDate? occurrenceDate,
  }) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => EditEventScreen(
            eventId: eventId,
            initialDate: initialDate,
            occurrenceDate: occurrenceDate,
          ),
        ),
      );

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends ConsumerState<EditEventScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Recurrence _recurrence = Recurrence.daily;
  int _timeOfDay = 8 * 60;
  late CalendarDate _startDate;
  CalendarDate? _endDate;
  List<int> _leadMinutes = const [15];
  int _colorValue = EventColors.fallback;
  int _daysOfWeek = Weekdays.none;
  int _interval = 2;
  int? _dayOfMonth;
  int? _placeId;
  bool _autoCompleteOnArrival = false;

  bool _loading = true;
  bool _saving = false;

  bool get _isNew => widget.eventId == null;

  @override
  void initState() {
    super.initState();
    _startDate =
        widget.initialDate ?? CalendarDate.fromDateTime(DateTime.now());
    _load();
  }

  Future<void> _load() async {
    final id = widget.eventId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final event = await ref.read(eventsDaoProvider).eventById(id);
    if (!mounted) return;
    if (event == null) {
      Navigator.of(context).pop();
      return;
    }
    _titleController.text = event.title;
    _notesController.text = event.notes ?? '';
    setState(() {
      _recurrence = event.recurrence;
      _timeOfDay = event.timeOfDay;
      _startDate = event.startDate;
      _endDate = event.endDate;
      _leadMinutes = event.leadMinutes;
      _colorValue = event.colorValue;
      _daysOfWeek = event.rule.daysOfWeek;
      _interval = event.rule.interval;
      _dayOfMonth = event.rule.dayOfMonth;
      _placeId = event.placeId;
      _autoCompleteOnArrival = event.autoCompleteOnArrival;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  EventRule get _draftRule => EventRule(
    recurrence: _recurrence,
    startDate: _startDate,
    timeOfDay: _timeOfDay,
    endDate: _recurrence == Recurrence.once ? null : _endDate,
    daysOfWeek: _daysOfWeek,
    interval: _interval,
    dayOfMonth: _dayOfMonth,
  );

  /// Whether the rule as drawn can ever produce an occurrence.
  ///
  /// The one way to build a rule that silently never fires is a weekly one
  /// with no days ticked, so Save refuses it rather than saving something
  /// inert.
  bool get _isFireable =>
      _recurrence != Recurrence.weekly || _daysOfWeek != Weekdays.none;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New event' : 'Edit event'),
        actions: [
          if (!_isNew)
            IconButton(
              onPressed: _saving ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            _Section(
              child: TextFormField(
                controller: _titleController,
                autofocus: _isNew,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: const InputDecoration(
                  hintText: 'What is it?',
                  border: InputBorder.none,
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Give it a name'
                    : null,
              ),
            ),
            const Divider(),
            _Row(
              icon: Icons.schedule,
              label: 'Time',
              value: formatWallClock(_timeOfDay),
              onTap: _pickTime,
            ),
            const Divider(),
            _RecurrencePicker(
              value: _recurrence,
              onChanged: _changeRecurrence,
            ),
            if (_recurrence == Recurrence.weekly)
              _WeekdayPicker(
                mask: _daysOfWeek,
                onChanged: (mask) => setState(() => _daysOfWeek = mask),
              ),
            if (_recurrence == Recurrence.everyNDays)
              _IntervalPicker(
                interval: _interval,
                onChanged: (value) => setState(() => _interval = value),
              ),
            if (_recurrence == Recurrence.monthly)
              _MonthDayPicker(
                dayOfMonth: _dayOfMonth ?? _startDate.day,
                onChanged: (value) => setState(() => _dayOfMonth = value),
              ),
            _Row(
              icon: _recurrence == Recurrence.once
                  ? Icons.event_outlined
                  : Icons.calendar_today_outlined,
              label: _recurrence == Recurrence.once ? 'Date' : 'Starts',
              value: formatMediumDate(_startDate),
              onTap: _pickStartDate,
            ),
            if (_recurrence != Recurrence.once) ...[
              const Divider(),
              _Row(
                icon: Icons.event_busy_outlined,
                label: 'Ends',
                value: _endDate == null ? 'Never' : formatMediumDate(_endDate!),
                onTap: _pickEndDate,
                onClear: _endDate == null
                    ? null
                    : () => setState(() => _endDate = null),
              ),
            ],
            _PreviewLine(rule: _draftRule),
            const Divider(),
            _LeadMinutesPicker(
              selected: _leadMinutes,
              onChanged: (value) => setState(() => _leadMinutes = value),
            ),
            const Divider(),
            _PlacePicker(
              placeId: _placeId,
              onChanged: (value) => setState(() {
                _placeId = value;
                // "Mark done on arrival" with nowhere to arrive at is a
                // promise the app cannot keep, so clearing the place clears
                // the switch with it rather than leaving it on and inert.
                if (value == null) _autoCompleteOnArrival = false;
              }),
              autoComplete: _autoCompleteOnArrival,
              onAutoCompleteChanged: (value) =>
                  setState(() => _autoCompleteOnArrival = value),
            ),
            const Divider(),
            _ColourPicker(
              selected: _colorValue,
              onChanged: (value) => setState(() => _colorValue = value),
            ),
            const Divider(),
            _Section(
              child: TextFormField(
                controller: _notesController,
                maxLines: null,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Notes',
                  border: InputBorder.none,
                  icon: Icon(Icons.notes),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _timeOfDay ~/ 60, minute: _timeOfDay % 60),
    );
    if (picked != null) {
      setState(() => _timeOfDay = picked.hour * 60 + picked.minute);
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await _pickDate(_startDate);
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // An end date that now precedes the start would silently kill the
        // series, so drop it rather than save something that never fires.
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await _pickDate(_endDate ?? _startDate, first: _startDate);
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<CalendarDate?> _pickDate(
    CalendarDate initial, {
    CalendarDate? first,
  }) async {
    final today = CalendarDate.fromDateTime(DateTime.now());
    final firstDate = first ?? today.addDays(-365);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.localDateTimeAt(12 * 60),
      firstDate: firstDate.localDateTimeAt(12 * 60),
      lastDate: today.addDays(365 * 5).localDateTimeAt(12 * 60),
    );
    return picked == null ? null : CalendarDate.fromDateTime(picked);
  }

  /// Fills in sensible defaults when the shape of the rule changes, so
  /// switching to Weekly does not land on a rule that never fires.
  void _changeRecurrence(Recurrence value) {
    setState(() {
      _recurrence = value;
      if (value == Recurrence.weekly && _daysOfWeek == Weekdays.none) {
        _daysOfWeek = Weekdays.bit(_startDate.weekday);
      }
      if (value == Recurrence.monthly) {
        _dayOfMonth ??= _startDate.day;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_isFireable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one day of the week')),
      );
      return;
    }
    setState(() => _saving = true);

    final notes = _notesController.text.trim();
    final dao = ref.read(eventsDaoProvider);
    final companion = EventsCompanion(
      id: _isNew ? const Value.absent() : Value(widget.eventId!),
      title: Value(_titleController.text.trim()),
      notes: Value(notes.isEmpty ? null : notes),
      colorValue: Value(_colorValue),
      timeOfDay: Value(_timeOfDay),
      durationMin: const Value(null),
      recurrence: Value(_recurrence),
      daysOfWeek: Value(
        _recurrence == Recurrence.weekly ? _daysOfWeek : Weekdays.none,
      ),
      interval: Value(_recurrence == Recurrence.everyNDays ? _interval : 1),
      dayOfMonth: Value(
        _recurrence == Recurrence.monthly
            ? (_dayOfMonth ?? _startDate.day)
            : null,
      ),
      startDate: Value(_startDate),
      endDate: Value(_recurrence == Recurrence.once ? null : _endDate),
      leadMinutes: Value(_leadMinutes),
      isActive: const Value(true),
      placeId: Value(_placeId),
      autoCompleteOnArrival:
          Value(_placeId != null && _autoCompleteOnArrival),
      // Saving from the editor is the user taking ownership. A row the app
      // wrote to record a visit becomes an ordinary event of theirs — it stops
      // being tidied away with the visit history, and a later departure stops
      // reaching in to rewrite its duration.
      fromVisitId: const Value(null),
    );

    if (_isNew) {
      await dao.insertEvent(companion);
    } else {
      await dao.updateEvent(companion);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final scope = await showDeleteScopeSheet(
      context,
      title: _titleController.text.trim(),
      recurrence: _recurrence,
      occurrenceDate: widget.occurrenceDate,
    );
    if (scope == null || !mounted) return;

    final dao = ref.read(eventsDaoProvider);
    final id = widget.eventId!;
    final date = widget.occurrenceDate;

    switch (scope) {
      case DeleteScope.thisOccurrence:
        await dao.deleteOccurrence(id, date!);
      case DeleteScope.thisAndFollowing:
        await dao.deleteOccurrencesFrom(id, date!);
      case DeleteScope.allOccurrences:
        await dao.deleteEvent(id);
    }
    if (mounted) Navigator.of(context).pop();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: DaylineTheme.gutter,
      vertical: 12,
    ),
    child: child,
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      minTileHeight: DaylineTheme.rowMinHeight,
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.primary)
                .merge(monospacedFigures),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Clear',
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _RecurrencePicker extends StatelessWidget {
  const _RecurrencePicker({required this.value, required this.onChanged});

  final Recurrence value;
  final ValueChanged<Recurrence> onChanged;

  static const _labels = {
    Recurrence.once: 'Once',
    Recurrence.daily: 'Daily',
    Recurrence.weekly: 'Weekly',
    Recurrence.everyNDays: 'Every N days',
    Recurrence.monthly: 'Monthly',
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      DaylineTheme.gutter,
      14,
      DaylineTheme.gutter,
      4,
    ),
    // Chips rather than a segmented button: five options do not fit across a
    // phone, and a segmented button has no way to wrap.
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final recurrence in EditEventScreen.supportedRecurrences)
          ChoiceChip(
            label: Text(_labels[recurrence]!),
            selected: recurrence == value,
            onSelected: (isOn) {
              if (isOn) onChanged(recurrence);
            },
          ),
      ],
    ),
  );
}

/// Which days of the week a WEEKLY rule fires on.
class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.mask, required this.onChanged});

  final int mask;
  final ValueChanged<int> onChanged;

  static const _initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        10,
        DaylineTheme.gutter,
        6,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var weekday = DateTime.monday;
              weekday <= DateTime.sunday;
              weekday++)
            () {
              final isOn = Weekdays.contains(mask, weekday);
              return Semantics(
                selected: isOn,
                button: true,
                label: _names[weekday - 1],
                child: InkWell(
                  key: ValueKey('weekday-$weekday'),
                  onTap: () => onChanged(mask ^ Weekdays.bit(weekday)),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOn ? scheme.primary : Colors.transparent,
                      border: Border.all(
                        color: isOn ? scheme.primary : scheme.outline,
                      ),
                    ),
                    child: Text(
                      _initials[weekday - 1],
                      style: TextStyle(
                        color: isOn ? scheme.onPrimary : scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }(),
        ],
      ),
    );
  }
}

/// The N in "every N days".
class _IntervalPicker extends StatelessWidget {
  const _IntervalPicker({required this.interval, required this.onChanged});

  final int interval;
  final ValueChanged<int> onChanged;

  static const _min = 2;
  static const _max = 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        4,
        DaylineTheme.gutter,
        4,
      ),
      child: Row(
        children: [
          Icon(Icons.repeat_one, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Text('Every', style: theme.textTheme.titleMedium),
          const Spacer(),
          IconButton(
            // An interval of 1 is Daily, which is its own option; letting it
            // be picked here would give two ways to say the same thing.
            onPressed: interval > _min ? () => onChanged(interval - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$interval',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)
                  .merge(monospacedFigures),
            ),
          ),
          IconButton(
            onPressed: interval < _max ? () => onChanged(interval + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
          const SizedBox(width: 4),
          Text('days', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

/// Which day of the month a MONTHLY rule lands on.
class _MonthDayPicker extends StatelessWidget {
  const _MonthDayPicker({required this.dayOfMonth, required this.onChanged});

  final int dayOfMonth;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLastDay = dayOfMonth == -1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        10,
        DaylineTheme.gutter,
        6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var day = 1; day <= 31; day++)
                () {
                  final isOn = day == dayOfMonth;
                  return InkWell(
                    onTap: () => onChanged(day),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOn ? scheme.primary : Colors.transparent,
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: isOn ? scheme.onPrimary : scheme.onSurface,
                          fontWeight:
                              isOn ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }(),
            ],
          ),
          const SizedBox(height: 6),
          // Distinct from picking 31: "the last day" means the 28th in
          // February, where the 31st clamps back to it only as a fallback.
          FilterChip(
            label: const Text('Last day of the month'),
            selected: isLastDay,
            onSelected: (isOn) => onChanged(isOn ? -1 : 1),
          ),
          if (dayOfMonth > 28 && !isLastDay)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Short months fall back to their last day, so this never '
                'skips a month.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The sentence that tells the user what they have actually built.
class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.rule});

  final EventRule rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DaylineTheme.gutter, 4,
          DaylineTheme.gutter, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.repeat, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              describeRule(rule),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadMinutesPicker extends StatelessWidget {
  const _LeadMinutesPicker({required this.selected, required this.onChanged});

  final List<int> selected;
  final ValueChanged<List<int>> onChanged;

  static const _options = <int, String>{
    0: 'At time',
    5: '5m',
    10: '10m',
    15: '15m',
    30: '30m',
    60: '1h',
    120: '2h',
    1440: '1 day',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DaylineTheme.gutter, 14,
          DaylineTheme.gutter, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_none,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Text('Remind me', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final MapEntry(key: minutes, value: label)
                  in _options.entries)
                FilterChip(
                  label: Text(label),
                  selected: selected.contains(minutes),
                  onSelected: (isOn) {
                    // Kept sorted furthest-out first, which is the order the
                    // reminders will actually arrive in.
                    final next = [...selected];
                    isOn ? next.add(minutes) : next.remove(minutes);
                    next.sort((a, b) => b.compareTo(a));
                    onChanged(next);
                  },
                ),
            ],
          ),
          if (selected.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'No reminder — this will only appear on the list.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColourPicker extends StatelessWidget {
  const _ColourPicker({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(DaylineTheme.gutter, 14,
          DaylineTheme.gutter, 14),
      child: Row(
        children: [
          Icon(Icons.palette_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                for (final value in EventColors.all)
                  Semantics(
                    selected: value == selected,
                    button: true,
                    child: InkWell(
                      onTap: () => onChanged(value),
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: EventColors.of(value),
                            shape: BoxShape.circle,
                            border: value == selected
                                ? Border.all(color: scheme.onSurface, width: 3)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Optionally ties this routine to a place, and offers to let arriving there
/// tick it off.
///
/// Only offered when the user has places at all — a picker whose only option
/// is "nowhere" is a row that teaches nothing.
class _PlacePicker extends ConsumerWidget {
  const _PlacePicker({
    required this.placeId,
    required this.onChanged,
    required this.autoComplete,
    required this.onAutoCompleteChanged,
  });

  final int? placeId;
  final ValueChanged<int?> onChanged;

  /// Whether arriving at the picked place marks the occurrence done.
  final bool autoComplete;
  final ValueChanged<bool> onAutoCompleteChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(placesProvider).value ?? const <Place>[];
    if (places.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        14,
        DaylineTheme.gutter,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Text('Where', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Anywhere'),
                selected: placeId == null,
                onSelected: (isOn) {
                  if (isOn) onChanged(null);
                },
              ),
              for (final place in places)
                ChoiceChip(
                  label: Text(place.name),
                  selected: place.id == placeId,
                  onSelected: (isOn) => onChanged(isOn ? place.id : null),
                ),
            ],
          ),
          if (placeId != null) ...[
            const SizedBox(height: 10),
            Text(
              'The dashboard will show whether you were actually there.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            _AutoCompleteSwitch(
              value: autoComplete,
              onChanged: onAutoCompleteChanged,
            ),
          ],
        ],
      ),
    );
  }
}

/// "Mark done when I get there".
///
/// Only ever shown with a place already picked, because arriving nowhere in
/// particular is not an event. It also says plainly when it cannot work: with
/// only "while using" location the OS never wakes the app, and a switch that
/// silently does nothing is worse than one that admits it.
class _AutoCompleteSwitch extends ConsumerWidget {
  const _AutoCompleteSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Null while the permission is still being read — no claim either way
    // until it is known.
    final hasBackground = ref.watch(backgroundLocationProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const ValueKey('auto-complete-switch'),
          contentPadding: EdgeInsets.zero,
          value: value,
          onChanged: onChanged,
          title: const Text('Mark done on arrival'),
          subtitle: const Text(
            'Tick this off by itself when you get there around the time it '
            'is due',
          ),
          secondary: Icon(
            Icons.where_to_vote_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (value && hasBackground == false)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Background location is off, so nothing will be marked '
                    'until you allow it in Settings.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
