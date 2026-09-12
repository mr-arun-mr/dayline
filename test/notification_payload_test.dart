import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/notifications/notification_payload.dart';
import 'package:test/test.dart';

void main() {
  test('round trips a dated payload', () {
    const payload = NotificationPayload(
      eventId: 7,
      leadMinutes: 15,
      date: CalendarDate(2026, 9, 11),
    );
    final decoded = NotificationPayload.decode(payload.encode());

    expect(decoded.eventId, 7);
    expect(decoded.leadMinutes, 15);
    expect(decoded.date, const CalendarDate(2026, 9, 11));
  });

  test('round trips a repeating payload, which has no date', () {
    const payload = NotificationPayload(eventId: 7, leadMinutes: 60);
    final decoded = NotificationPayload.decode(payload.encode());

    expect(decoded.date, isNull);
    expect(decoded.leadMinutes, 60);
  });

  group('working out which occurrence fired', () {
    test('a dated payload just says so', () {
      const payload = NotificationPayload(
        eventId: 1,
        leadMinutes: 15,
        date: CalendarDate(2026, 9, 11),
      );
      // Even if the device fires it late, the date it was scheduled for wins.
      expect(
        payload.occurrenceDateFor(DateTime(2026, 9, 12, 1, 0)),
        const CalendarDate(2026, 9, 11),
      );
    });

    test('a repeating payload uses the firing time plus its lead', () {
      const payload = NotificationPayload(eventId: 1, leadMinutes: 15);
      expect(
        payload.occurrenceDateFor(DateTime(2026, 9, 11, 6, 45)),
        const CalendarDate(2026, 9, 11),
      );
    });

    test('a repeating reminder that fires before midnight belongs to the '
        'next day', () {
      // An hour before a 00:30 event: fires at 23:30 on the 11th, for the 12th.
      const payload = NotificationPayload(eventId: 1, leadMinutes: 60);
      expect(
        payload.occurrenceDateFor(DateTime(2026, 9, 11, 23, 30)),
        const CalendarDate(2026, 9, 12),
        reason: 'using the firing date would mark the wrong day done',
      );
    });

    test('a zero lead belongs to the day it fires on', () {
      const payload = NotificationPayload(eventId: 1, leadMinutes: 0);
      expect(
        payload.occurrenceDateFor(DateTime(2026, 9, 11, 7, 0)),
        const CalendarDate(2026, 9, 11),
      );
    });
  });

  group('malformed payloads', () {
    test('tryDecode swallows rubbish rather than killing the handler', () {
      expect(NotificationPayload.tryDecode(null), isNull);
      expect(NotificationPayload.tryDecode(''), isNull);
      expect(NotificationPayload.tryDecode('not json'), isNull);
      expect(NotificationPayload.tryDecode('[]'), isNull);
      expect(NotificationPayload.tryDecode('{"e":1}'), isNull);
    });

    test('decode is strict where a caller can handle it', () {
      expect(() => NotificationPayload.decode('[]'), throwsFormatException);
    });
  });
}
