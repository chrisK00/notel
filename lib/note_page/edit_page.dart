import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notel/infrastructure/note.dart';
import 'package:notel/search/search_query.dart';
import 'package:notel/utils/extensions.dart';
import '../notes_provider.dart';
import 'note_page_repository.dart';
import 'note_base_page.dart';

class EditPage extends StatefulWidget {
  const EditPage({
    super.key,
    required this.noteId,
    this.initialNote,
    this.highlightQuery,
  });

  final int noteId;
  final Note? initialNote;
  final SearchQuery? highlightQuery;

  @override
  State<StatefulWidget> createState() => _EditPageState();
}

class _EditPageState extends NoteBasePage<EditPage> {
  @override
  void initState() {
    if (widget.initialNote != null) {
      note = widget.initialNote!;
      if (!note.title.isNullOrWhitespace()) {
        textEditingController.text = note.title!;
      }
      if (note.displayText.isNotEmpty) {
        try {
          final json = jsonDecode(note.displayText);
          controller.document = Document.fromJson(json);
        } catch (_) {}
      }
      if (widget.highlightQuery != null) {
        highlightSearchTerms(widget.highlightQuery);
      }
    }
    super.initState();
  }

  @override
  Future initNote() async {
    final fetched = await NotePageRepository.getNoteById(widget.noteId);
    if (!mounted) return;
    note = fetched;
    if (!note.title.isNullOrWhitespace() && textEditingController.text != note.title) {
      textEditingController.text = note.title!;
    }

    if (note.displayText.isEmpty) {
      if (widget.highlightQuery != null && searchMatches.isEmpty) {
        highlightSearchTerms(widget.highlightQuery);
      }
      return;
    }

    try {
      final json = jsonDecode(note.displayText);
      final newDoc = Document.fromJson(json);
      if (controller.document.toPlainText() != newDoc.toPlainText()) {
        setState(() {
          controller.document = newDoc;
        });
        if (widget.highlightQuery != null) {
          highlightSearchTerms(widget.highlightQuery);
        }
      } else if (widget.highlightQuery != null && searchMatches.isEmpty) {
        highlightSearchTerms(widget.highlightQuery);
      }
    } catch (_) {}
  }

  @override
  Future navigateToPreviousPage(
      BuildContext context, NotesProvider provider) async {
    if (note.displayText.isEmptyOrWhitespace() &&
        note.title.isNullOrWhitespace()) {
      await provider.remove(note.id);
    } else {
      provider.update(note.id);
    }
  }
}
