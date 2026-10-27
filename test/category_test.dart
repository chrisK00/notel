import 'package:flutter_test/flutter_test.dart';
import 'package:notel/infrastructure/category.dart';
import 'package:notel/infrastructure/date_only.dart';
import 'package:notel/infrastructure/note.dart';

void main() {
  group('Category model tests', () {
    test('toMap and fromMap roundtrip', () {
      final cat = Category(
        id: 1,
        name: 'Work',
        showNoteDate: false,
        showLastModified: true,
      );
      final map = cat.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Work');
      expect(map['showNoteDate'], 0);
      expect(map['showLastModified'], 1);

      final reconstructed = Category.fromMap(map);
      expect(reconstructed.id, 1);
      expect(reconstructed.name, 'Work');
      expect(reconstructed.showNoteDate, isFalse);
      expect(reconstructed.showLastModified, isTrue);
    });

    test('missing category display settings use compatible defaults', () {
      final category = Category.fromMap({'id': 1, 'name': 'Existing'});

      expect(category.showNoteDate, isTrue);
      expect(category.showLastModified, isNull);
    });

    test('Note model categoryId serialization', () {
      final note = Note(
        id: 10,
        title: 'Meeting',
        displayText: 'Discuss roadmap',
        date: const DateOnly(2026, 8, 28),
        categoryId: 5,
      );

      final map = note.toMap();
      expect(map['categoryId'], 5);

      final reconstructed = Note.fromMap(map);
      expect(reconstructed.id, 10);
      expect(reconstructed.title, 'Meeting');
      expect(reconstructed.categoryId, 5);
    });

    test('Note without categoryId defaults to null', () {
      final note = Note(id: 1, displayText: 'Simple');
      expect(note.categoryId, isNull);

      final map = note.toMap();
      expect(map['categoryId'], isNull);

      final reconstructed = Note.fromMap(map);
      expect(reconstructed.categoryId, isNull);
    });
  });
}
