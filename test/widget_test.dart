import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notel/note_page/notel_clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NotelClipboard rich copy and paste preserves styling across controllers', () async {
    // Document 1 with rich formatting:
    final doc1 = Document()
      ..insert(0, 'Important Note\n')
      ..format(0, 14, Attribute.h1)
      ..insert(15, 'This is bold and green text\n')
      ..format(23, 4, Attribute.bold)
      ..format(32, 5, const ColorAttribute('#00FF00'));

    final controller1 = QuillController(
      document: doc1,
      selection: const TextSelection(baseOffset: 0, extentOffset: 43),
    );

    // Copy via NotelClipboard:
    NotelClipboard.copySelection(controller1);
    expect(NotelClipboard.hasData, isTrue);

    // Open Document 2 (empty note):
    final doc2 = Document();
    final controller2 = QuillController(
      document: doc2,
      selection: const TextSelection.collapsed(offset: 0),
    );

    // Paste via NotelClipboard:
    await NotelClipboard.pasteClipboard(controller2);

    final doc2Delta = controller2.document.toDelta();
    expect(doc2Delta.toString().contains('Important Note'), isTrue);
    expect(doc2Delta.toString().contains('bold'), isTrue);
    expect(doc2Delta.toString().contains('#00FF00'), isTrue);
  });

  test('Cancel and re-listen during formatText drops highlight changes', () async {
    final doc = Document()..insert(0, 'Hello world, this is a test note about zoloft and health.');
    final controller = QuillController(
      document: doc,
      selection: const TextSelection(baseOffset: 0, extentOffset: 0),
    );

    var hasUnsaved = false;
    StreamSubscription<DocChange>? sub;
    void attach() {
      sub = controller.document.changes.listen((event) {
        hasUnsaved = true;
      });
    }
    attach();

    // Now clear highlights:
    await sub?.cancel();
    final clearAttr = Attribute.clone(Attribute.background, null);
    controller.formatText(33, 6, clearAttr);
    attach();

    await pumpEventQueue();

    expect(hasUnsaved, isFalse);
  });

  test('Custom time shortcut replaces typed sequence with timestamp', () {
    final doc = Document()..insert(0, 'Log entry ');
    final controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 10),
    );

    const timeShortcut = '//';
    // User types '/' then '/'
    controller.replaceText(10, 0, '//', const TextSelection.collapsed(offset: 12));

    final baseOffset = controller.selection.baseOffset;
    final plainText = controller.document.toPlainText();
    final start = baseOffset - timeShortcut.length;
    final typed = plainText.substring(start, start + timeShortcut.length);
    expect(typed, '//');

    final hour = DateTime.now().hour.toString().padLeft(2, '0');
    final minute = DateTime.now().minute.toString().padLeft(2, '0');
    final replacement = '$hour.$minute ';

    controller.replaceText(start, timeShortcut.length, replacement, TextSelection.collapsed(offset: start + replacement.length));
    controller.formatText(start, replacement.length, Attribute.bold);

    expect(controller.document.toPlainText().startsWith('Log entry $hour.$minute '), isTrue);
  });
}

