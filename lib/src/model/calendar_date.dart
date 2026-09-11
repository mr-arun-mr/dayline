/// A timezone-free calendar date: year, month, day, and nothing else.
///
/// Dayline never does recurrence arithmetic on [DateTime]. A [DateTime] carries
/// a UTC offset, and adding `Duration(days: 1)` across a DST boundary lands you
/// on the wrong wall clock — 07:00 gym becomes 06:00 or 08:00. That is the one
/// bug this app is not allowed to have, so every rule expansion happens here,
/// on integers, and a wall-clock [DateTime] is only ever constructed at the
/// very edge (notification scheduling, display).
class CalendarDate implements Comparable<CalendarDate> {
  const CalendarDate(this.year, this.month, this.day);

  /// The calendar date [dt] falls on, in whatever zone [dt] is expressed in.
  factory CalendarDate.fromDateTime(DateTime dt) =>
      CalendarDate(dt.year, dt.month, dt.day);

  /// Days since 1970-01-01 in the proleptic Gregorian calendar.
  ///
  /// Howard Hinnant's `civil_from_days`. Exact for any year, no floating
  /// point, no timezone, no leap-second nonsense.
  factory CalendarDate.fromEpochDay(int epochDay) {
    final z = epochDay + 719468;
    final era = (z >= 0 ? z : z - 146096) ~/ 146097;
    final doe = z - era * 146097; // [0, 146096]
    final yoe =
        (doe - doe ~/ 1460 + doe ~/ 36524 - doe ~/ 146096) ~/ 365; // [0, 399]
    final y = yoe + era * 400;
    final doy = doe - (365 * yoe + yoe ~/ 4 - yoe ~/ 100); // [0, 365]
    final mp = (5 * doy + 2) ~/ 153; // [0, 11]
    final d = doy - (153 * mp + 2) ~/ 5 + 1; // [1, 31]
    final m = mp + (mp < 10 ? 3 : -9); // [1, 12]
    return CalendarDate(y + (m <= 2 ? 1 : 0), m, d);
  }

  /// Parses `yyyy-MM-dd`.
  factory CalendarDate.parse(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) {
      throw FormatException('Expected yyyy-MM-dd', iso);
    }
    return CalendarDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  final int year;

  /// 1..12
  final int month;

  /// 1..31
  final int day;

  /// Days since 1970-01-01. Hinnant's `days_from_civil`.
  int get epochDay {
    final y = year - (month <= 2 ? 1 : 0);
    final era = (y >= 0 ? y : y - 399) ~/ 400;
    final yoe = y - era * 400; // [0, 399]
    final doy =
        (153 * (month + (month > 2 ? -3 : 9)) + 2) ~/ 5 + day - 1; // [0, 365]
    final doe = yoe * 365 + yoe ~/ 4 - yoe ~/ 100 + doy; // [0, 146096]
    return era * 146097 + doe - 719468;
  }

  /// ISO-8601 weekday: 1 = Monday … 7 = Sunday.
  ///
  /// 1970-01-01 (epoch day 0) was a Thursday, hence the +3.
  int get weekday => ((epochDay + 3) % 7) + 1;

  CalendarDate addDays(int days) => CalendarDate.fromEpochDay(epochDay + days);

  /// Whole days from this date to [other]; negative if [other] is earlier.
  int daysUntil(CalendarDate other) => other.epochDay - epochDay;

  /// This date's wall clock at [minuteOfDay] minutes past midnight, as a
  /// **local** [DateTime]. Dart resolves the local offset for us, so 07:00 on
  /// either side of a DST change is still 07:00 to the user.
  ///
  /// On a spring-forward day the 02:00–03:00 wall clock does not exist; Dart
  /// normalises such a time forward to 03:00, which is what a user expects
  /// from an alarm on that day.
  DateTime localDateTimeAt(int minuteOfDay) =>
      DateTime(year, month, day, minuteOfDay ~/ 60, minuteOfDay % 60);

  static bool isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  static int daysInMonth(int year, int month) {
    const lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && isLeapYear(year)) return 29;
    return lengths[month - 1];
  }

  /// Pins a nominal day-of-month onto a month that may be shorter.
  ///
  /// "The 31st" in February means the 28th (or 29th); a monthly rent reminder
  /// must not silently skip a month. [day] may also be negative to count back
  /// from the end, where -1 is the last day of the month.
  static int clampDayOfMonth(int day, int year, int month) {
    final length = daysInMonth(year, month);
    if (day < 0) {
      final fromEnd = length + 1 + day;
      return fromEnd < 1 ? 1 : fromEnd;
    }
    if (day < 1) return 1;
    return day > length ? length : day;
  }

  bool isBefore(CalendarDate other) => compareTo(other) < 0;

  bool isAfter(CalendarDate other) => compareTo(other) > 0;

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// `yyyy-MM-dd`.
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
