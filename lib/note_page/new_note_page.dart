import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notel/infrastructure/note.dart';
import 'package:notel/note_page/note_page_repository.dart';
import 'package:notel/note_page/note_base_page.dart';
import 'package:notel/notes_provider.dart';
import 'package:notel/utils/extensions.dart';

class NewNotePage extends StatefulWidget {
  const NewNotePage({super.key, this.categoryId, this.templateNote});

  final int? categoryId;

  /// When set, the new note is pre-populated with this note's content and title.
  final Note? templateNote;

  @override
  State<StatefulWidget> createState() => _NewNotePageState();
}

class _NewNotePageState extends NoteBasePage<NewNotePage> {
  @override
  bool get isNewNote => true;

  @override
  Future initNote() async {
    final template = widget.templateNote;
    final categoryId = widget.categoryId ?? template?.categoryId;

    note = await NotePageRepository.createNote(categoryId: categoryId);

    if (template != null) {
      // Pre-populate with the template's title (without a "(copy)" suffix —
      // the user is authoring a fresh note, not a duplicate).
      if (!template.title.isNullOrWhitespace()) {
        note.title = template.title;
        textEditingController.text = template.title!;
        await NotePageRepository.updateNoteTitle(note.id, template.title);
      }

      // Pre-populate with the template's body.
      if (template.displayText.isNotEmpty) {
        try {
          final json = jsonDecode(template.displayText);
          setState(() {
            controller.document = Document.fromJson(json);
          });
        } catch (_) {}
        // Persist to DB so the note is consistent if the app is backgrounded.
        await NotePageRepository.updateNoteText(note.id, template.displayText);
        note.displayText = template.displayText;
      }
    }
  }

  @override
  Future navigateToPreviousPage(
      BuildContext context, NotesProvider provider) async {
    if (note.displayText.isEmptyOrWhitespace() &&
        note.title.isNullOrWhitespace()) {
      await provider.remove(note.id);
    } else {
      await provider.update(note.id);
    }
  }
}
