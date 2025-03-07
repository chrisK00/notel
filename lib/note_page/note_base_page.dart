import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';
import 'package:notel/dialogs/yes_or_no_dialog.dart';
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
  var _lastAddedText = "";
  final TextEditingController textEditingController = TextEditingController();

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

  Future _onSave(NotesProvider notesProvider) async {
    setState(() => _hasUnsavedChanges = false);
    final json = jsonEncode(controller.document.toDelta().toJson());
    try {
      final changesMade =
          await NotePageRepository.updateNoteText(note.id, json);

      note.displayText =
          Note.trimNoteDisplayText(controller.document.toPlainText());
      log('Updated rows $changesMade');

      note.title = textEditingController.text;
      final changesMadeForTitle =
          await NotePageRepository.updateNoteTitle(note.id, note.title);
      log('Updated titles $changesMadeForTitle');
      await notesProvider.update(note.id);
    } catch (e) {
      setState(() => _hasUnsavedChanges = true);
      log('Update failed', error: e);
    }
  }

  void _insertTimeShortcut(DocChange event) {
    final operations = event.change.operations;

    if (!operations.last.isInsert) {
      return;
    }

    final addedText = operations.last.data as String;
    if (addedText != "." ||
        _lastAddedText != "." ||
        controller.selection.baseOffset < 2) {
      _lastAddedText = addedText;
      return;
    }

    final hour = DateTime.now().hour.toString().padLeft(2, '0');
    final minute = DateTime.now().minute.toString().padLeft(2, '0');
    final replacementText = "$hour.$minute ";

    final start = controller.selection.baseOffset - 2;
    const length = 2;

    controller.replaceText(start, length, replacementText,
        TextSelection.collapsed(offset: start + replacementText.length));

    controller.formatText(
      start,
      replacementText.length,
      Attribute.bold,
    );

    controller.formatSelection(Attribute.clone(Attribute.bold, null));

    _lastAddedText = addedText;
  }

  void onTextChanged(DocChange event) {
    log('Text changed: $event');
    setState(() => _hasUnsavedChanges = true);

    _insertTimeShortcut(event);
  }

// TODO move this to edit page?
  void setCaretToEnd() =>
      controller.moveCursorToPosition(controller.document.length);

  Future _showSaveDialog(NotesProvider notesProvider) async {
    if (_hasUnsavedChanges) {
      final shouldSave = await showDialog<bool>(
          context: context,
          builder: (context) => const YesOrNoDialog(
              title: "Save changes?",
              dangerBtnText: "ignore",
              successBtnText: "Save"));

      if (shouldSave == true) {
        await _onSave(notesProvider);
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
            body: Column(
          children: [
            actions(context, provider),
            Expanded(
                child: QuillEditor.basic(
                    focusNode: _focusNode,
                    configurations: QuillEditorConfigurations(
                        autoFocus: true,
                        controller: controller,
                        padding:
                            const EdgeInsets.only(left: 25, right: 25, top: 20),
                        expands: true))),
            NoteTextToolbar(controller: controller),
          ],
        )),
      );
    });
  }

  Widget actions(BuildContext context, NotesProvider notesProvider) {
    return Padding(
      padding: const EdgeInsets.only(right: 5, left: 5),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              PopupMenuButton<int>(
                  offset: Offset.fromDirection(3, 30),
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (selected) async {
                    switch (selected) {
                      case 1:
                        final shouldCancel = await showDialog<bool>(
                            context: context,
                            builder: (context) => const YesOrNoDialog(
                                title: "Delete Note?",
                                dangerBtnText: "Delete",
                                successBtnText: "Cancel"));

                        if (shouldCancel == null || shouldCancel) {
                          return;
                        }

                        await notesProvider.remove(note.id);
                        note.displayText = "";
                        Navigator.pop(context);
                        break;
                      default:
                    }
                  },
                  iconColor:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.7),
                  itemBuilder: (context) => [
                        const PopupMenuItem<int>(
                          value: 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [Icon(Icons.delete), Text("delete")],
                          ),
                        )
                      ])
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                    iconSize: 30,
                    onPressed: () async {
                      await _showSaveDialog(notesProvider);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back)),
                Column(
                  children: [
                    TextButton(
                        onPressed: () async => await updateDate(notesProvider),
                        child: Text(
                          DateFormat('d MMMM yyyy').format(note.date),
                        )),
                    SizedBox(
                      width: 250,
                      height: 40,
                      child: Opacity(
                          opacity: 0.9,
                          child: TextField(
                            controller: textEditingController,
                            onChanged: (_) =>
                                setState(() => _hasUnsavedChanges = true),
                          )),
                    )
                  ],
                ),
                saveButton(notesProvider)
              ],
            ),
          ),
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

  Widget saveButton(notesProvider) {
    return Opacity(
      opacity: _hasUnsavedChanges ? 1 : 0,
      child: IconButton(
          iconSize: 30,
          onPressed: () async => _onSave(notesProvider),
          icon: Icon(Icons.save, color: Theme.of(context).colorScheme.primary)),
    );
  }
}
