import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notel/db.dart';

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

  Future<void> _loadNote() async {
    final db = await Db.open();
    if (widget.noteId == null) {
      _note.id = await db.insert(Db.noteTable, _note.toMap());
      _controller.document.changes.listen(_onTextChanged);
    } else {
      final getNoteResult = await db.query(Db.noteTable,
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

    // TODO: if note exists fetch from DB, else create new. Delete note if empty?
    log('Existing NoteId: ${widget.noteId}');
    _loadNote().then((_) => {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future _onSave() async {
    // TODO kanske ska använda changes ist o inserta det typ?? eller liknande bättre prestanda
    // _controller.changes
    setState(() => _hasUnsavedChanges = false);
    final json = jsonEncode(_controller.document.toDelta().toJson());
    // TODO: borde vara i ett repo
    final db = await Db.open();
    try {
      final changesMade = await db
          .rawUpdate('UPDATE NOTE SET TEXT = ? WHERE id = ?', [json, _note.id]);
      log(changesMade.toString());
    } catch (e) {
      setState(() => _hasUnsavedChanges = true);
      log('Failed to update note', error: e);
    }
  }

// TODO: save button should be displayed when changes have been made
  void _onTextChanged(event) {
    log('Text changed: $event');
    setState(() => _hasUnsavedChanges = true);
    // https://stackoverflow.com/questions/71815023/dart-how-to-listen-for-text-change-in-quill-text-editor-flutter
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color.fromARGB(255, 224, 234, 238),
        body: Container(
            margin: const EdgeInsets.only(top: 30),
            child: Column(
              children: [
                actions(context),
                // https://www.youtube.com/watch?v=L2qG-qlhx-s&list=PLzzt2WMkurR2kE9TPm4BwW5XrvdavgZiV&index=3
                // TODO at top of screen back < button and save button and inbetween add also editable note date
                // TODO tags would be nice, e.g huvudvärk, or maybe just implement a good search feature that counts results words (if duplicated word in a day only take 1)
                // TODO: move toolbar to bottom of screen

                Expanded(
                    child: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 10),
                  child: QuillEditor.basic(
                      configurations: QuillEditorConfigurations(
                          controller: _controller, expands: true)),
                )),
                textToolbar(),
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
      final db = await Db.open();
      db.delete(Db.noteTable, where: 'id = ?', whereArgs: [_note.id]);
    }

    Navigator.pop(context, true);
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

  QuillSimpleToolbar textToolbar() => QuillToolbar.simple(
        configurations: QuillSimpleToolbarConfigurations(
          showFontFamily: false,
          showCodeBlock: false,
          showUnderLineButton: false,
          showSubscript: false,
          showSuperscript: false,
          showClearFormat: false,
          showIndent: false,
          showLink: false,
          showClipboardCopy: false,
          showClipboardCut: false,
          showInlineCode: false,
          multiRowsDisplay: false,
          controller: _controller,
        ),
      );
}

class SaveChangesDialog extends StatelessWidget {
  const SaveChangesDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text("Save changes?"),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          Container(
            color: const Color.fromARGB(255, 231, 104, 93),
            child: SimpleDialogOption(
              child: const Text('ignore'),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
          Container(
            color: const Color.fromARGB(255, 144, 214, 223),
            child: SimpleDialogOption(
              child: const Text('Save'),
              onPressed: () => Navigator.pop(context, true),
            ),
          )
        ])
      ],
    );
  }
}
