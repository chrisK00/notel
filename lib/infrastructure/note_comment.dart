class NoteComment {
  const NoteComment({
    required this.id,
    required this.noteId,
    required this.parentId,
    required this.quotedText,
    required this.startOffset,
    required this.endOffset,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final int noteId;
  final int? parentId;
  final String quotedText;
  final int startOffset;
  final int endOffset;
  final String body;
  final DateTime createdAt;

  factory NoteComment.fromMap(Map<String, Object?> map) {
    return NoteComment(
      id: map['id'] as int,
      noteId: map['noteId'] as int,
      parentId: map['parentId'] as int?,
      quotedText: map['quotedText'] as String,
      startOffset: map['startOffset'] as int,
      endOffset: map['endOffset'] as int,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
