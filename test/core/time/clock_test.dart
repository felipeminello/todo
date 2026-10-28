import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/core/time/clock.dart';

import '../../helpers/fixed_clock.dart';

void main() {
  test('today from a fixed clock is its local calendar day', () {
    final clock = FixedClock(DateTime(2026, 10, 27, 22, 30));

    expect(CalendarDate.fromLocal(clock.now()), CalendarDate(2026, 10, 27));
  });

  test('advancing a fixed clock past midnight changes the day', () {
    final clock = FixedClock(DateTime(2026, 10, 27, 23, 30))
      ..advance(const Duration(hours: 1));

    expect(CalendarDate.fromLocal(clock.now()), CalendarDate(2026, 10, 28));
  });

  test('system clock returns the current local time', () {
    final before = DateTime.now();
    final now = const SystemClock().now();

    expect(now.isUtc, isFalse);
    expect(now.isBefore(before), isFalse);
  });
}
