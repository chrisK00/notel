class Note {
  Note({this.id, this.text = "", DateTime? date})
      : date = date ?? DateTime.now();
  int? id; // TODO doesnt make sense to not have an id
  String text = "";
  DateTime date = DateTime.now();

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'text': text,
      'date': date.toString(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      text: map['text'] ?? '',
      date: DateTime.parse(map['date']),
    );
  }

  @override
  String toString() {
    return 'Note{id: $id, date: $date, text length: ${text.length}}';
  }
}
