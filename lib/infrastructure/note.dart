import 'dart:math';

class Note {
  Note({required this.id, this.displayText = "", DateTime? date})
      : date = date ?? DateTime.now();
  int id;
  String displayText;
  DateTime date;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'text': displayText,
      'date': date.toString(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      displayText: map['text'] ?? '',
      date: DateTime.parse(map['date']),
    );
  }

  @override
  String toString() {
    return 'Note{id: $id, date: $date, text length: ${displayText.length}}';
  }

  static String trimNoteDisplayText(String text) {
    const int noteDisplayTextLength = 36;
    final cutOfLength = min(noteDisplayTextLength, text.length);
    return text.substring(0, cutOfLength);
  }
}
