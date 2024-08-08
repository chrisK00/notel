import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notel/dialogs/save_changes_dialog.dart';
import 'package:notel/infrastructure/note.dart';
import 'package:notel/note_page/note_page_repository.dart';
import 'package:notel/note_page/note_text_toolbar.dart';
import 'package:notel/notes_provider.dart';
import 'package:provider/provider.dart';

abstract class NoteBasePage<T extends StatefulWidget> extends State<T> {
  final controller = QuillController.basic();
  Note note = Note(id: 0);
  var _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    initNote().then((_) => {});
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future initNote();
  Future navigateToPreviousPage(BuildContext context, NotesProvider provider);

  Future _onSave() async {
    setState(() => _hasUnsavedChanges = false);
    final json = jsonEncode(controller.document.toDelta().toJson());
    try {
      final changesMade = await NotePageRepository.updateNote(note.id, json);

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
            backgroundColor: const Color.fromARGB(255, 224, 234, 238),
            body: Container(
                margin: const EdgeInsets.only(top: 70),
                child: Column(
                  children: [
                    actions(context, provider),
                    Expanded(
                        child: Padding(
                      padding:
                          const EdgeInsets.only(left: 20, right: 20, top: 15),
                      child: QuillEditor.basic(
                          configurations: QuillEditorConfigurations(
                              controller: controller, expands: true)),
                    )),
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
          saveButton()
        ],
      ),
    );
  }

  Visibility saveButton() {
    return Visibility(
      visible: _hasUnsavedChanges,
      child: IconButton(
          iconSize: 30,
          onPressed: () async => _onSave(),
          icon: const Icon(Icons.save)),
    );
  }
}
