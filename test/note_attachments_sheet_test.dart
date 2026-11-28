import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notel/note_page/note_attachments_sheet.dart';

void main() {
  test('extracts unique links and image embeds from a note document', () {
    final document = Document.fromJson([
      {
        'insert': 'Training plan',
        'attributes': {'link': 'https://example.com/plan'},
      },
      {'insert': '\n'},
      {
        'insert': 'Training plan',
        'attributes': {'link': 'https://example.com/plan'},
      },
      {'insert': '\n'},
      {
        'insert': {'image': 'https://example.com/bench-press.png'},
      },
      {'insert': '\n'},
    ]);

    final attachments = NoteAttachment.fromDocument(document);

    expect(attachments, hasLength(2));
    expect(attachments.first.type, NoteAttachmentType.link);
    expect(attachments.first.label, 'Training plan');
    expect(attachments.last.type, NoteAttachmentType.image);
  });

  test('extracts raw URLs from plain text if no link attribute', () {
    final document = Document.fromJson([
      {
        'insert': 'Check out https://flutter.dev for info\n',
      },
    ]);

    final attachments = NoteAttachment.fromDocument(document);

    expect(attachments, hasLength(1));
    expect(attachments.first.type, NoteAttachmentType.link);
    expect(attachments.first.value, 'https://flutter.dev');
  });

  testWidgets('shows an empty state when the note has no attachments',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: NoteAttachmentsSheet(document: Document())),
    ));

    expect(find.text('Attachments'), findsOneWidget);
    expect(find.text('No links or images in this note yet.'), findsOneWidget);
  });
}
