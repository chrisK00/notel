import 'dart:math';

class Note {
  Note({required this.id, this.displayText = "", this.title, DateTime? date})
      : date = date ?? DateTime.now();
  int id;
  String displayText;
  DateTime date;
  String? title;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'text': displayText,
      'date': date.toString(),
      'title': title?.toString()
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
        id: map['id'],
        displayText: map['text'] ?? '',
        date: DateTime.parse(map['date']),
        title: map["title"]);
  }

  @override
  String toString() {
    return 'Note{title: $title, id: $id, date: $date, text length: ${displayText.length}}';
  }

  static String trimNoteDisplayText(String text) {
    const int noteDisplayTextLength = 36;
    final cutOfLength = min(noteDisplayTextLength, text.length);
    return text.substring(0, cutOfLength);
  }
}
