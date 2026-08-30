import 'dart:math';
import 'date_only.dart';

class Note {
  Note(
      {required this.id,
      this.displayText = "",
      this.title,
      DateOnly? date,
      this.lastModified,
      this.categoryId,
      this.hidden = false})
      : date = date ?? DateOnly.today();
  int id;
  String displayText;
  DateOnly date;
  DateTime? lastModified;
  String? title;
  int? categoryId;
  bool hidden;

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'text': displayText,
      'date': date.toString(), // stored as "yyyy-MM-dd"
      'title': title?.toString(),
      'lastModified': lastModified?.toString(),
      'categoryId': categoryId,
      'hidden': hidden ? 1 : 0,
    };
    if (id != 0) {
      map['id'] = id;
    }
    return map;
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
        id: map['id'],
        displayText: map['text'] ?? '',
        date: DateOnly.parse(map['date']),
        lastModified: map['lastModified'] == null ? null : DateTime.parse(map['lastModified']),
        title: map["title"],
        categoryId: map['categoryId'], hidden: map['hidden'] == 1 || map['hidden'] == true);
  }

  @override
  String toString() {
    return 'Note{title: $title, id: $id, date: $date, categoryId: $categoryId, text length: ${displayText.length}}';
  }

  static String trimNoteDisplayText(String text) {
    const int noteDisplayTextLength = 36;
    final cutOfLength = min(noteDisplayTextLength, text.length);
    return text.substring(0, cutOfLength);
  }
}
