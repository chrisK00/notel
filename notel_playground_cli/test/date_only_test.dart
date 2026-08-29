import 'package:test/test.dart';
import 'package:notel_playground_cli/date_only.dart';

void main() {
  group('DateOnly', () {
    test('constructor assigns year, month, day', () {
      const d = DateOnly(2026, 8, 28);
      expect(d.year, 2026);
      expect(d.month, 8);
      expect(d.day, 28);
    });

    test('toString formats as yyyy-MM-dd with leading zeros', () {
      const d1 = DateOnly(2026, 8, 5);
      expect(d1.toString(), '2026-08-05');

      const d2 = DateOnly(2026, 12, 25);
      expect(d2.toString(), '2026-12-25');
    });

    test('fromDateTime extracts date components', () {
      final dt = DateTime(2026, 5, 14, 18, 45, 30);
      final d = DateOnly.fromDateTime(dt);
      expect(d.year, 2026);
      expect(d.month, 5);
      expect(d.day, 14);
    });

    test('toDateTime returns DateTime at midnight', () {
      const d = DateOnly(2026, 8, 28);
      final dt = d.toDateTime();
      expect(dt.year, 2026);
      expect(dt.month, 8);
      expect(dt.day, 28);
      expect(dt.hour, 0);
      expect(dt.minute, 0);
      expect(dt.second, 0);
    });

    test('today returns current date', () {
      final now = DateTime.now();
      final today = DateOnly.today();
      expect(today.year, now.year);
      expect(today.month, now.month);
      expect(today.day, now.day);
      expect(today.isToday(), isTrue);
    });

    test('parse standard yyyy-MM-dd string', () {
      final d = DateOnly.parse('2026-03-09');
      expect(d, const DateOnly(2026, 3, 9));
      expect(d.toString(), '2026-03-09');
    });

    test('parse backwards compatibility with full ISO timestamp', () {
      final d1 = DateOnly.parse('2025-11-20T14:32:00.000Z');
      expect(d1.year, 2025);
      expect(d1.month, 11);
      expect(d1.day, 20);

      final d2 = DateOnly.parse('2025-01-05 10:20:30.123');
      expect(d2.year, 2025);
      expect(d2.month, 1);
      expect(d2.day, 5);
    });

    test('isSameDay checks equality of date components', () {
      const d1 = DateOnly(2026, 8, 28);
      const d2 = DateOnly(2026, 8, 28);
      const d3 = DateOnly(2026, 8, 29);

      expect(d1.isSameDay(d2), isTrue);
      expect(d1.isSameDay(d3), isFalse);
    });

    test('equality and hashCode', () {
      const d1 = DateOnly(2026, 8, 28);
      const d2 = DateOnly(2026, 8, 28);
      const d3 = DateOnly(2026, 9, 1);

      expect(d1 == d2, isTrue);
      expect(d1 == d3, isFalse);
      expect(d1.hashCode, d2.hashCode);
    });

    test('compareTo sorts chronologically', () {
      const past = DateOnly(2025, 12, 31);
      const mid = DateOnly(2026, 1, 1);
      const future = DateOnly(2026, 8, 28);

      expect(past.compareTo(mid), lessThan(0));
      expect(mid.compareTo(past), greaterThan(0));
      expect(mid.compareTo(mid), 0);

      final list = [future, past, mid];
      list.sort();
      expect(list, [past, mid, future]);
    });
  });
}
