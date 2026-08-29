import 'package:test/test.dart';
import 'package:notel_playground_cli/date_only.dart';
import 'package:notel_playground_cli/note.dart';

void main() {
  group('Note Model', () {
    test('Note.toMap and Note.fromMap round-trip with all fields', () {
      final lastMod = DateTime(2026, 8, 28, 20, 15, 30);
      final note = Note(
        id: 42,
        title: 'Project Roadmap',
        displayText: '{"ops":[{"insert":"Hello World\\n"}]}',
        date: const DateOnly(2026, 8, 28),
        lastModified: lastMod,
        categoryId: 7,
      );

      final map = note.toMap();
      expect(map['id'], 42);
      expect(map['title'], 'Project Roadmap');
      expect(map['text'], '{"ops":[{"insert":"Hello World\\n"}]}');
      expect(map['date'], '2026-08-28');
      expect(map['lastModified'], lastMod.toString());
      expect(map['categoryId'], 7);

      final restored = Note.fromMap(map);
      expect(restored.id, 42);
      expect(restored.title, 'Project Roadmap');
      expect(restored.displayText, '{"ops":[{"insert":"Hello World\\n"}]}');
      expect(restored.date, const DateOnly(2026, 8, 28));
      expect(restored.lastModified, lastMod);
      expect(restored.categoryId, 7);
    });

    test('Note.toMap excludes id when id is 0 (for new row insertion)', () {
      final note = Note(
        id: 0,
        title: 'New Note',
        displayText: 'Draft text',
      );

      final map = note.toMap();
      expect(map.containsKey('id'), isFalse);
      expect(map['title'], 'New Note');
      expect(map['text'], 'Draft text');
    });

    test('Note.fromMap handles null and missing optional fields', () {
      final map = <String, dynamic>{
        'id': 100,
        'date': '2026-05-12',
      };

      final note = Note.fromMap(map);
      expect(note.id, 100);
      expect(note.displayText, '');
      expect(note.title, isNull);
      expect(note.lastModified, isNull);
      expect(note.categoryId, isNull);
      expect(note.date, const DateOnly(2026, 5, 12));
    });

    test('trimNoteDisplayText limits string length to 36 chars', () {
      expect(Note.trimNoteDisplayText('Short text'), 'Short text');
      expect(
        Note.trimNoteDisplayText('This is a very long text that exceeds the maximum preview display length'),
        'This is a very long text that exceed',
      );
      expect(
        Note.trimNoteDisplayText('This is a very long text that exceeds the maximum preview display length').length,
        36,
      );
    });

    test('Note.toString contains metadata', () {
      final note = Note(
        id: 5,
        title: 'Meeting Notes',
        displayText: 'Discuss quarterly targets',
        date: const DateOnly(2026, 8, 28),
        categoryId: 2,
      );

      final str = note.toString();
      expect(str.contains('title: Meeting Notes'), isTrue);
      expect(str.contains('id: 5'), isTrue);
      expect(str.contains('2026-08-28'), isTrue);
      expect(str.contains('categoryId: 2'), isTrue);
      expect(str.contains('text length: 25'), isTrue);
    });
  });
}
