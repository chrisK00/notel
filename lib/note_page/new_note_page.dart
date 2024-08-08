import 'package:flutter/material.dart';
import 'package:notel/note_page/note_page_repository.dart';
import 'package:notel/note_page/note_base_page.dart';
import 'package:notel/notes_provider.dart';

class NewNotePage extends StatefulWidget {
  const NewNotePage({super.key});

  @override
  State<StatefulWidget> createState() => _NewNotePageState();
}

class _NewNotePageState extends NoteBasePage<NewNotePage> {
  @override
  Future initNote() async {
    note = await NotePageRepository.createNote();
    controller.document.changes.listen(onTextChanged);
  }

  @override
  Future navigateToPreviousPage(
      BuildContext context, NotesProvider provider) async {
    if (note.displayText.trim().isEmpty) {
      await provider.remove(note.id);
    } else {
      provider.add(note);
    }
  }
}
