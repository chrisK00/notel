import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../notes_provider.dart';
import 'note_page_repository.dart';
import 'note_base_page.dart';

class EditPage extends StatefulWidget {
  const EditPage({super.key, required this.noteId});

  final int noteId;

  @override
  State<StatefulWidget> createState() => _EditPageState();
}

class _EditPageState extends NoteBasePage<EditPage> {
  @override
  Future initNote() async {
    note = await NotePageRepository.getNoteById(widget.noteId);
    if (note.displayText.isEmpty) {
      controller.document.changes.listen(onTextChanged);
      return;
    }

    final json = jsonDecode(note.displayText);
    setState(() {
      controller.document = Document.fromJson(json);
      controller.document.changes.listen(onTextChanged);
    });
  }

  @override
  Future navigateToPreviousPage(
      BuildContext context, NotesProvider provider) async {
    if (note.displayText.trim().isEmpty) {
      await provider.remove(note.id);
    } else {
      provider.update(note.id);
    }
  }
}
