import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notel/infrastructure/db.dart';
import '../dialogs/save_changes_dialog.dart';
import 'note_text_toolbar.dart';

class EditPage extends StatefulWidget {
  const EditPage(
      {super.key, this.noteId, this.onUpdate, this.onCreate, this.onRemove});

  final int? noteId;
  final Function? onRemove;
  final Function? onUpdate;
  final Function(int)? onCreate;

  @override
  State<StatefulWidget> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  final _controller = QuillController.basic();
  var _hasUnsavedChanges = false;
  var _note = Note();
  bool _isNewNote = false;

  Future<void> _loadNote() async {
    if (widget.noteId == null) {
      _note.id = await Db.instance.insert(Db.noteTable, _note.toMap());
      _controller.document.changes.listen(_onTextChanged);
      _isNewNote = true;
    } else {
      final getNoteResult = await Db.instance.query(Db.noteTable,
          where: "id= ?", whereArgs: [widget.noteId], limit: 1);
      _note = Note.fromMap(getNoteResult.first);

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
  }

  @override
  void initState() {
    super.initState();
    log('Existing NoteId: ${widget.noteId}');
    _loadNote().then((_) => {});
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
      final changesMade = await Db.instance.update(Db.noteTable, {'TEXT': json},
          where: 'id = ?', whereArgs: [_note.id]);
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
    return Scaffold(
        backgroundColor: const Color.fromARGB(255, 224, 234, 238),
        body: Container(
            margin: const EdgeInsets.only(top: 30),
            child: Column(
              children: [
                actions(context),
                Expanded(
                    child: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 10),
                  child: QuillEditor.basic(
                      configurations: QuillEditorConfigurations(
                          controller: _controller, expands: true)),
                )),
                NoteTextToolbar(controller: _controller),
              ],
            )));
  }

  Future navigateToPreviousPage(BuildContext context) async {
    if (_hasUnsavedChanges) {
      final shouldSave = await showDialog<bool>(
          context: context, builder: (context) => const SaveChangesDialog());

      if (shouldSave == true) {
        await _onSave();
      }
    }

    if (_controller.document.toPlainText().trim().isEmpty) {
      await Db.instance
          .delete(Db.noteTable, where: 'id = ?', whereArgs: [_note.id]);
      widget.onRemove?.call();
      Navigator.pop(context);
    } else if (_isNewNote) {
      widget.onCreate?.call(_note.id!);
      Navigator.pop(context);
    } else {
      widget.onUpdate?.call();
      Navigator.pop(context);
    }
  }

  Padding actions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 1, right: 3, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
              iconSize: 30,
              onPressed: () async => await navigateToPreviousPage(context),
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
