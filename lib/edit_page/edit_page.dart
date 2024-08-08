import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import '../dialogs/save_changes_dialog.dart';
import '../infrastructure/note.dart';
import '../notes_provider.dart';
import 'edit_page_repository.dart';
import 'note_text_toolbar.dart';

class EditPage extends StatefulWidget {
  const EditPage({super.key, this.noteId});

  final int? noteId;

  @override
  State<StatefulWidget> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  final _controller = QuillController.basic();
  var _hasUnsavedChanges = false;
  var _note = Note();
  bool _isNewNote = false;
  bool _hasPopped = false;

  Future initExistingNote(Note note) async {
    _note = note;

    if (_note.text.isEmpty) {
      _controller.document.changes.listen(_onTextChanged);
      return;
    }

    final json = jsonDecode(_note.text);
    setState(() {
      _controller.document = Document.fromJson(json);
      _controller.document.changes.listen(_onTextChanged);
    });
  }

  Future createNote() async {
    _note.id = await EditPageRepository.createNote(_note);
    _controller.document.changes.listen(_onTextChanged);
    _isNewNote = true;
  }

  Future initNote() async {
    if (widget.noteId == null) {
      await createNote();
    } else {
      await initExistingNote(
          await EditPageRepository.getNoteById(widget.noteId!));
    }
  }

  @override
  void initState() {
    super.initState();
    log('Existing NoteId: ${widget.noteId}');
    initNote().then((_) => {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future _onSave() async {
    setState(() => _hasUnsavedChanges = false);
    final json = jsonEncode(_controller.document.toDelta().toJson());
    try {
      final changesMade = await EditPageRepository.updateNote(_note.id!, json);
      log('Updated rows $changesMade');
    } catch (e) {
      setState(() => _hasUnsavedChanges = true);
      log('Update failed', error: e);
    }
  }

  void _onTextChanged(event) {
    log('Text changed: $event');
    setState(() => _hasUnsavedChanges = true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(builder: (context, provider, child) {
      return PopScope(
        onPopInvoked: (didPop) {
          if (didPop) {
            onPagePop(context, provider, didPop = true);
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
                              controller: _controller, expands: true)),
                    )),
                    NoteTextToolbar(controller: _controller),
                  ],
                ))),
      );
    });
  }

  Future onPagePop(
      BuildContext context, NotesProvider provider, bool didPop) async {
    if (_hasPopped) {
      return;
    }

    await navigateToPreviousPage(context, provider, didPop);
  }

  Future navigateToPreviousPage(BuildContext context, NotesProvider provider,
      [bool didPop = false]) async {
    _hasPopped = true;
    if (!didPop) {
      if (_hasUnsavedChanges) {
        // TODO:  once we fix so that dialog can be displayed onPop we can get rid of the _hasPopped hack
        final shouldSave = await showDialog<bool>(
            context: context, builder: (context) => const SaveChangesDialog());

        if (shouldSave == true) {
          await _onSave();
        }
      }
    }

    _note.text = _controller.document.toPlainText();
    if (_note.text.trim().isEmpty) {
      await provider.remove(_note.id!);
    } else if (_isNewNote) {
      provider.add(_note);
    } else {
      provider.update(_note);
    }

    if (!didPop) {
      Navigator.pop(context);
    }
  }

  Padding actions(BuildContext context, NotesProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, right: 5, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
              iconSize: 30,
              onPressed: () async =>
                  await navigateToPreviousPage(context, provider),
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
