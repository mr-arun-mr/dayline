import 'dart:convert';

import '../model/calendar_date.dart';

/// What a notification carries so that tapping Done or Snooze knows what it is
/// about.
///
/// The awkward case is the repeating trigger: it fires forever from one slot,
/// so it cannot carry the date of the occurrence it belongs to. Instead it
/// carries the lead, and the date is worked out from when the notification
/// actually fired — a reminder an hour before a 00:30 event fires at 23:30 and
/// belongs to *tomorrow*, which is exactly the case that a naive "use today"
/// would get wrong.
class NotificationPayload {
  const NotificationPayload({
    required this.eventId,
    required this.leadMinutes,
    this.date,
  });

  factory NotificationPayload.decode(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map) throw const FormatException('Not a payload object');
    final epochDay = json['d'];
    return NotificationPayload(
      eventId: (json['e'] as num).toInt(),
      leadMinutes: (json['l'] as num).toInt(),
      date: epochDay == null
          ? null
          : CalendarDate.fromEpochDay((epochDay as num).toInt()),
    );
  }

  /// Returns null rather than throwing, for the notification-tap path where a
  /// malformed payload should be ignored, not crash a background isolate.
  static NotificationPayload? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return NotificationPayload.decode(raw);
    } on Object {
      return null;
    }
  }

  final int eventId;
  final int leadMinutes;

  /// The occurrence's date, when the reminder was scheduled for one specific
  /// day. Null for repeating triggers.
  final CalendarDate? date;

  String encode() => jsonEncode({
    'e': eventId,
    'l': leadMinutes,
    if (date != null) 'd': date!.epochDay,
  });

  /// Which occurrence this notification is about, given when it fired.
  ///
  /// For a dated payload that is simply the stored date. For a repeating one
  /// it is the day the *event* falls on, which is the firing moment plus the
  /// lead that was subtracted to get there.
  CalendarDate occurrenceDateFor(DateTime firedAt) =>
      date ?? CalendarDate.fromDateTime(
        firedAt.add(Duration(minutes: leadMinutes)),
      );
}

/// Action button identifiers, shared between the scheduling side and the
/// handler that receives the tap.
abstract final class NotificationActions {
  static const done = 'dayline.done';
  static const snooze = 'dayline.snooze';

  /// How long Snooze pushes a reminder back.
  static const snoozeDuration = Duration(minutes: 10);

  /// The iOS category that carries the two buttons.
  static const category = 'dayline.reminder';
}
