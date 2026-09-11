import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/database.dart';
import '../../model/calendar_date.dart';
import '../../model/recurrence.dart';
import '../../model/rule_description.dart';
import '../../providers.dart';
import '../event_colors.dart';
import '../theme.dart';
import 'delete_scope_sheet.dart';

/// Add or edit one rule.
///
/// Step 2 offers ONCE and DAILY only; the picker is built as a list of
/// [Recurrence] values so the remaining three drop in without restructuring.
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

  static const supportedRecurrences = [Recurrence.once, Recurrence.daily];

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
  );

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
              onChanged: (value) => setState(() => _recurrence = value),
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
      daysOfWeek: const Value(Weekdays.none),
      interval: const Value(1),
      dayOfMonth: const Value(null),
      startDate: Value(_startDate),
      endDate: Value(_recurrence == Recurrence.once ? null : _endDate),
      leadMinutes: Value(_leadMinutes),
      isActive: const Value(true),
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
    Recurrence.daily: 'Every day',
    Recurrence.weekly: 'Weekly',
    Recurrence.everyNDays: 'Every N days',
    Recurrence.monthly: 'Monthly',
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(DaylineTheme.gutter, 12, 
        DaylineTheme.gutter, 4),
    child: SegmentedButton<Recurrence>(
      segments: [
        for (final recurrence in EditEventScreen.supportedRecurrences)
          ButtonSegment(
            value: recurrence,
            label: Text(_labels[recurrence]!),
          ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.single),
      showSelectedIcon: false,
    ),
  );
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
