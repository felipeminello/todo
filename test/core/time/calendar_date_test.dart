import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/time/calendar_date.dart';

void main() {
  group('CalendarDate', () {
    test('formats as YYYY-MM-DD with zero padding', () {
      expect(CalendarDate(2026, 1, 5).toIso(), '2026-01-05');
      expect(CalendarDate(2026, 10, 27).toIso(), '2026-10-27');
    });

    test('parses YYYY-MM-DD', () {
      expect(CalendarDate.fromIso('2026-10-27'), CalendarDate(2026, 10, 27));
    });

    test('round-trips through ISO without shifting the day', () {
      final date = CalendarDate(2026, 10, 27);
      expect(CalendarDate.fromIso(date.toIso()), date);
    });

    test('rejects malformed strings', () {
      for (final value in [
        '',
        '2026-10',
        '27/10/2026',
        '2026-10-27T00:00:00Z',
        '2026-1-5',
        ' 2026-10-27',
      ]) {
        expect(
          () => CalendarDate.fromIso(value),
          throwsFormatException,
          reason: value,
        );
      }
    });

    test('rejects impossible days', () {
      expect(() => CalendarDate.fromIso('2026-02-30'), throwsFormatException);
      expect(() => CalendarDate.fromIso('2026-13-01'), throwsFormatException);
      expect(() => CalendarDate(2026, 4, 31), throwsArgumentError);
    });

    test('accepts leap day only in leap years', () {
      expect(CalendarDate(2028, 2, 29).toIso(), '2028-02-29');
      expect(() => CalendarDate(2026, 2, 29), throwsArgumentError);
    });

    test('compares by value', () {
      expect(CalendarDate(2026, 10, 27), CalendarDate(2026, 10, 27));
      expect(CalendarDate(2026, 10, 27), isNot(CalendarDate(2026, 10, 28)));
    });

    test('orders chronologically across month and year boundaries', () {
      final dates = [
        CalendarDate(2027, 1, 1),
        CalendarDate(2026, 11, 1),
        CalendarDate(2026, 12, 31),
        CalendarDate(2026, 10, 31),
      ]..sort();

      expect(dates, [
        CalendarDate(2026, 10, 31),
        CalendarDate(2026, 11, 1),
        CalendarDate(2026, 12, 31),
        CalendarDate(2027, 1, 1),
      ]);
    });

    test('isBefore and isAfter', () {
      final today = CalendarDate(2026, 10, 27);
      expect(CalendarDate(2026, 10, 26).isBefore(today), isTrue);
      expect(today.isBefore(today), isFalse);
      expect(CalendarDate(2026, 10, 28).isAfter(today), isTrue);
      expect(today.isAfter(today), isFalse);
    });

    test('fromLocal takes the local calendar day, ignoring the time', () {
      expect(
        CalendarDate.fromLocal(DateTime(2026, 10, 27, 23, 59)),
        CalendarDate(2026, 10, 27),
      );
      expect(
        CalendarDate.fromLocal(DateTime(2026, 10, 27)),
        CalendarDate(2026, 10, 27),
      );
    });

    test('fromLocal converts UTC instants to the local day', () {
      final instant = DateTime.utc(2026, 10, 27, 12);
      final local = instant.toLocal();
      expect(
        CalendarDate.fromLocal(instant),
        CalendarDate(local.year, local.month, local.day),
      );
    });

    test('toLocalDateTime is local midnight of the same day', () {
      final dateTime = CalendarDate(2026, 10, 27).toLocalDateTime();
      expect(dateTime.isUtc, isFalse);
      expect(CalendarDate.fromLocal(dateTime), CalendarDate(2026, 10, 27));
    });
  });
}
