import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/database.dart';
import '../../model/calendar_date.dart';
import '../../model/holiday.dart';
import '../../model/rule_description.dart';
import '../../providers.dart';
import '../theme.dart';
import 'holidays_screen.dart';

/// Add or edit one holiday.
class EditHolidayScreen extends ConsumerStatefulWidget {
  const EditHolidayScreen({this.holidayId, super.key});

  final int? holidayId;

  static Future<void> open(BuildContext context, {int? holidayId}) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => EditHolidayScreen(holidayId: holidayId),
        ),
      );

  @override
  ConsumerState<EditHolidayScreen> createState() => _EditHolidayScreenState();
}

class _EditHolidayScreenState extends ConsumerState<EditHolidayScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late CalendarDate _startDate;
  late CalendarDate _endDate;
  int _scopes = HolidayScopes.everything;

  bool _loading = true;
  bool _saving = false;

  bool get _isNew => widget.holidayId == null;

  @override
  void initState() {
    super.initState();
    final today = CalendarDate.fromDateTime(DateTime.now());
    _startDate = today;
    _endDate = today;
    _load();
  }

  Future<void> _load() async {
    final id = widget.holidayId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final holiday = await ref.read(holidaysDaoProvider).holidayById(id);
    if (!mounted) return;
    if (holiday == null) {
      Navigator.of(context).pop();
      return;
    }
    _nameController.text = holiday.name;
    setState(() {
      _startDate = holiday.startDate;
      _endDate = holiday.endDate;
      _scopes = holiday.scopes;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New holiday' : 'Edit holiday'),
        actions: [
          if (!_isNew)
            IconButton(
              onPressed: _saving ? null : _delete,
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
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DaylineTheme.gutter,
                vertical: 12,
              ),
              child: TextFormField(
                controller: _nameController,
                autofocus: _isNew,
                textCapitalization: TextCapitalization.sentences,
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: const InputDecoration(
                  hintText: 'What is the day off?',
                  border: InputBorder.none,
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Give it a name' : null,
              ),
            ),
            const Divider(),
            _DateRow(
              icon: Icons.event_outlined,
              label: 'From',
              value: formatMediumDate(_startDate),
              onTap: _pickStart,
            ),
            const Divider(),
            _DateRow(
              icon: Icons.event_available_outlined,
              label: 'To',
              value: _endDate == _startDate
                  ? 'Same day'
                  : formatMediumDate(_endDate),
              onTap: _pickEnd,
              onClear: _endDate == _startDate
                  ? null
                  : () => setState(() => _endDate = _startDate),
            ),
            _Summary(startDate: _startDate, endDate: _endDate, scopes: _scopes),
            const Divider(),
            _ScopePicker(
              scopes: _scopes,
              onChanged: (value) => setState(() => _scopes = value),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStart() async {
    final picked = await _pickDate(_startDate);
    if (picked == null) return;
    setState(() {
      // Dragging the start past the end would leave a holiday that covers no
      // days at all, so the end follows it rather than silently inverting.
      if (_endDate.isBefore(picked)) _endDate = picked;
      _startDate = picked;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDate(_endDate, first: _startDate);
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
    if (_scopes == HolidayScopes.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick what is closed')),
      );
      return;
    }
    setState(() => _saving = true);

    final dao = ref.read(holidaysDaoProvider);
    final companion = HolidaysCompanion(
      id: _isNew ? const Value.absent() : Value(widget.holidayId!),
      name: Value(_nameController.text.trim()),
      startDate: Value(_startDate),
      endDate: Value(_endDate),
      scopes: Value(_scopes),
    );

    if (_isNew) {
      await dao.insertHoliday(companion);
    } else {
      await dao.updateHoliday(companion);
    }
    // The schedule is holding alarms for days that no longer happen.
    await ref.read(notificationServiceProvider).reconcile();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await ref.read(holidaysDaoProvider).deleteHoliday(widget.holidayId!);
    await ref.read(notificationServiceProvider).reconcile();
    if (mounted) Navigator.of(context).pop();
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
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
              tooltip: 'Just the one day',
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// The plain-English line that says what has actually been built, matching the
/// sentence the event editor shows under a recurrence rule.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.startDate,
    required this.endDate,
    required this.scopes,
  });

  final CalendarDate startDate;
  final CalendarDate endDate;
  final int scopes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = startDate.daysUntil(endDate) + 1;
    final closed = HolidayScopes.from(scopes);

    final what = closed.isEmpty
        ? 'Nothing steps aside — pick what is closed'
        : '${closed.map(describeScope).join(' and ')} '
            '${closed.length == 1 ? 'steps' : 'step'} aside';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        4,
        DaylineTheme.gutter,
        16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.beach_access, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              days == 1 ? '$what for the day' : '$what for $days days',
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

class _ScopePicker extends StatelessWidget {
  const _ScopePicker({required this.scopes, required this.onChanged});

  final int scopes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
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
              Icon(Icons.domain_disabled_outlined,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Text("What's closed", style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final scope in HolidayScope.values)
                FilterChip(
                  key: ValueKey('scope-${scope.name}'),
                  label: Text(describeScope(scope)),
                  selected: HolidayScopes.contains(scopes, scope),
                  onSelected: (isOn) =>
                      onChanged(isOn ? scopes | scope.bit : scopes & ~scope.bit),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Only events you have put on one of these timetables step aside. '
            'Everything else — medication, the gym, feeding the cat — happens '
            'as usual.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
