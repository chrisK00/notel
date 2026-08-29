import 'package:flutter_test/flutter_test.dart';
import 'package:notel/infrastructure/category.dart';
import 'package:notel/infrastructure/date_only.dart';
import 'package:notel/infrastructure/note.dart';

void main() {
  group('Category model tests', () {
    test('toMap and fromMap roundtrip', () {
      final cat = Category(id: 1, name: 'Work');
      final map = cat.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Work');

      final reconstructed = Category.fromMap(map);
      expect(reconstructed.id, 1);
      expect(reconstructed.name, 'Work');
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
