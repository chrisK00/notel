import 'package:flutter_test/flutter_test.dart';
import 'package:notel/activity_log/activity_calendar_date.dart';

void main() {
  final today = DateTime(2026, 11, 24, 21);

  test('describes selected calendar dates relative to today', () {
    expect(calendarDayDistanceLabel(DateTime(2026, 11, 24), today), 'Idag');
    expect(
        calendarDayDistanceLabel(DateTime(2026, 11, 23), today), '1 dag sedan');
    expect(calendarDayDistanceLabel(DateTime(2026, 11, 20), today),
        '4 dagar sedan');
    expect(calendarDayDistanceLabel(DateTime(2026, 11, 17), today),
        '1 vecka sedan');
    expect(calendarDayDistanceLabel(DateTime(2026, 11, 9), today),
        '2 veckor och 1 dag sedan');
    expect(calendarDayDistanceLabel(DateTime(2026, 9, 4), today),
        '2 månader, 2 veckor och 6 dagar sedan');
    expect(calendarDayDistanceLabel(DateTime(2025, 11, 24), today),
        '12 månader sedan');
    expect(calendarDayDistanceLabel(DateTime(2026, 7, 3), today),
        '4 månader och 3 veckor sedan');
    expect(
      calendarDayDistanceLabel(DateTime(2026, 3, 31), DateTime(2026, 5, 31)),
      '2 månader sedan',
    );
    expect(calendarDayDistanceLabel(DateTime(2026, 11, 25), today), 'Om 1 dag');
  });
}
