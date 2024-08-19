import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';
import 'package:notel/dialogs/save_changes_dialog.dart';
import 'package:notel/infrastructure/note.dart';
import 'package:notel/note_page/note_page_repository.dart';
import 'package:notel/note_page/note_text_toolbar.dart';
import 'package:notel/notes_provider.dart';
import 'package:provider/provider.dart';

abstract class NoteBasePage<T extends StatefulWidget> extends State<T> {
  final controller = QuillController.basic();
  final FocusNode _focusNode = FocusNode();
  Note note = Note(id: 0);
  var _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    initNote().then((_) => {setCaretToEnd()});
  }

  @override
  void dispose() {
    controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future initNote();
  Future navigateToPreviousPage(BuildContext context, NotesProvider provider);

  Future _onSave() async {
    setState(() => _hasUnsavedChanges = false);
    final json = jsonEncode(controller.document.toDelta().toJson());
    try {
      final changesMade =
          await NotePageRepository.updateNoteText(note.id, json);

      note.displayText =
          Note.trimNoteDisplayText(controller.document.toPlainText());
      log('Updated rows $changesMade');
    } catch (e) {
      setState(() => _hasUnsavedChanges = true);
      log('Update failed', error: e);
    }
  }

  void onTextChanged(event) {
    log('Text changed: $event');
    setState(() => _hasUnsavedChanges = true);
  }

  void setCaretToEnd() =>
      controller.moveCursorToPosition(controller.document.length);

  Future _showSaveDialog() async {
    if (_hasUnsavedChanges) {
      final shouldSave = await showDialog<bool>(
          context: context, builder: (context) => const SaveChangesDialog());

      if (shouldSave == true) {
        await _onSave();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(builder: (context, provider, child) {
      return PopScope(
        onPopInvoked: (didPop) async {
          if (didPop) {
            await navigateToPreviousPage(context, provider);
          }
        },
        child: Scaffold(
            body: Container(
                margin: const EdgeInsets.only(top: 70),
                child: Column(
                  children: [
                    actions(context, provider),
                    Expanded(
                        child: QuillEditor.basic(
                            focusNode: _focusNode,
                            configurations: QuillEditorConfigurations(
                                autoFocus: true,
                                controller: controller,
                                padding: const EdgeInsets.only(
                                    left: 25, right: 25, top: 20),
                                expands: true))),
                    NoteTextToolbar(controller: controller),
                  ],
                ))),
      );
    });
  }

  Padding actions(BuildContext context, NotesProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, right: 5, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
              iconSize: 30,
              onPressed: () async {
                await _showSaveDialog();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back)),
          TextButton(
              onPressed: () async => await updateDate(provider),
              child: Text(
                DateFormat('d MMMM yyyy').format(note.date),
                // style: const TextStyle(color: Colors.black),
              )),
          saveButton()
        ],
      ),
    );
  }

  Future updateDate(NotesProvider notesProvider) async {
    final today = DateTime.now();
    final newDate = await showDatePicker(
        initialDate: note.date,
        currentDate: note.date,
        context: context,
        firstDate: DateTime(today.year - 1, 1, 1),
        lastDate: today);
    if (newDate != null) {
      await NotePageRepository.updateNoteDate(note.id, newDate);
      setState(() {
        note.date = newDate;
      });
      notesProvider.update(note.id);
    }
  }

  Widget saveButton() {
    return Opacity(
      opacity: _hasUnsavedChanges ? 1 : 0,
      child: IconButton(
          iconSize: 30,
          onPressed: () async => _onSave(),
          icon: Icon(Icons.save, color: Theme.of(context).colorScheme.primary)),
    );
  }
}
