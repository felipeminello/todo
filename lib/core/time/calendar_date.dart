import 'package:equatable/equatable.dart';

/// A day on the calendar, with no time of day and no time zone.
///
/// Due dates are calendar days: storing them as instants would shift the day
/// when converted between time zones (e.g. midnight UTC is the previous day
/// in UTC-3).
final class CalendarDate extends Equatable implements Comparable<CalendarDate> {
  const CalendarDate._(this.year, this.month, this.day);

  factory CalendarDate(int year, int month, int day) {
    final normalized = DateTime.utc(year, month, day);
    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      throw ArgumentError('Invalid calendar date: $year-$month-$day');
    }
    return CalendarDate._(year, month, day);
  }

  /// The calendar day of [dateTime] as seen on the device's local calendar.
  factory CalendarDate.fromLocal(DateTime dateTime) {
    final local = dateTime.toLocal();
    return CalendarDate._(local.year, local.month, local.day);
  }

  /// Parses a `YYYY-MM-DD` string. Throws a [FormatException] otherwise.
  factory CalendarDate.fromIso(String value) {
    if (!_isoPattern.hasMatch(value)) {
      throw FormatException('Expected YYYY-MM-DD', value);
    }
    final [year, month, day] = value.split('-').map(int.parse).toList();
    try {
      return CalendarDate(year, month, day);
    } on ArgumentError {
      throw FormatException('Invalid calendar date', value);
    }
  }

  static final _isoPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  final int year;
  final int month;
  final int day;

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// Local midnight of this day, for widgets such as date pickers.
  DateTime toLocalDateTime() => DateTime(year, month, day);

  bool isBefore(CalendarDate other) => compareTo(other) < 0;

  bool isAfter(CalendarDate other) => compareTo(other) > 0;

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  List<Object> get props => [year, month, day];

  @override
  String toString() => toIso();
}
