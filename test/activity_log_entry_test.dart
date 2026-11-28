import 'package:flutter_test/flutter_test.dart';
import 'package:notel/activity_log/activity_log_entry.dart';
import 'package:notel/infrastructure/date_only.dart';
import 'package:notel/infrastructure/note.dart';

void main() {
  test('parses activity names and quantities from Quill note text', () {
    final note = Note(
      id: 7,
      date: const DateOnly(2026, 11, 24),
      lastModified: DateTime(2026, 11, 24, 9),
      displayText: '[{"insert":"'
          '08:00 start zo 25mg\\n'
          'start zo\\n'
          'stop zo 25 apa\\n'
          'start zo 25 mg\\n'
          'start desonix 2mg\\n'
          'ordinary text\\n'
          '"}]',
    );

    final entries = ActivityLogEntry.fromNote(note);

    expect(entries, hasLength(5));
    expect(entries[0].action, ActivityLogAction.start);
    expect(entries[0].activity, 'zo 25mg');
    expect(entries[0].activityName, 'zo');
    expect(entries[0].timestamp, DateTime(2026, 11, 24, 8));
    expect(entries[0].hasExplicitTime, isTrue);
    expect(entries[1].action, ActivityLogAction.start);
    expect(entries[1].activity, 'zo');
    expect(entries[1].timestamp, DateTime(2026, 11, 24, 9));
    expect(entries[1].hasExplicitTime, isFalse);
    expect(entries[2].action, ActivityLogAction.stop);
    expect(entries[2].activity, 'zo 25');
    expect(entries[3].activity, 'zo 25 mg');
    expect(entries[3].activityKey, entries[0].activityKey);
    expect(entries[2].activityKey, entries[0].activityKey);
    expect(entries[4].activityName, 'desonix');
    expect(entries[4].activity, 'desonix 2mg');
  });

  test('ignores invalid clock values and parses plain text notes', () {
    final note = Note(
      id: 8,
      date: const DateOnly(2026, 11, 24),
      displayText: '25:00 start invalid\nstart walk\n',
    );

    final entries = ActivityLogEntry.fromNote(note);

    expect(entries, hasLength(1));
    expect(entries.single.activity, 'walk');
    expect(entries.single.activityName, 'walk');
    expect(entries.single.timestamp, DateTime(2026, 11, 24));
    expect(entries.single.hasExplicitTime, isFalse);
  });

  test('parses dot-separated bold time before activity text', () {
    final note = Note(
      id: 9,
      date: const DateOnly(2026, 3, 5),
      displayText: '[{"insert":"23.00 ","attributes":{"bold":true}},'
          '{"insert":"start zo 25\\n"}]',
    );

    final entries = ActivityLogEntry.fromNote(note);

    expect(entries, hasLength(1));
    expect(entries.single.action, ActivityLogAction.start);
    expect(entries.single.activity, 'zo 25');
    expect(entries.single.timestamp, DateTime(2026, 3, 5, 23));
    expect(entries.single.hasExplicitTime, isTrue);
  });
}
