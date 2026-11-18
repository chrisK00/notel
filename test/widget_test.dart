import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notel/note_page/notel_clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'NotelClipboard rich copy and paste preserves styling across controllers',
      () async {
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

  test('NotelClipboard copies the current line when there is no selection',
      () async {
    final doc = Document()..insert(0, 'First line\nSecond line\nThird line\n');
    final source = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 13),
    );
    NotelClipboard.copyLine(source);

    final destination = QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
    await NotelClipboard.pasteClipboard(destination);

    expect(destination.document.toPlainText(), 'Second line\n\n');
  });

  test('NotelClipboard pastes the full URL without scheme as a link', () async {
    const url = 'https://www.koket.se/kolakakor-i-airfryer';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return {'text': url};
      }
      return null;
    });

    final controller = QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
    try {
      await NotelClipboard.pasteClipboard(controller);
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    }

    final delta = controller.document.toDelta().toString();
    expect(
      controller.document.toPlainText(),
      'www.koket.se/kolakakor-i-airfryer\n',
    );
    expect(delta, contains('https://www.koket.se/kolakakor-i-airfryer'));
    expect(
      controller.document
          .querySegmentLeafNode(0)
          .leaf
          ?.style
          .attributes[Attribute.link.key]
          ?.value,
      url,
    );
  });

  test('Cancel and re-listen during formatText drops highlight changes',
      () async {
    final doc = Document()
      ..insert(0, 'Hello world, this is a test note about zoloft and health.');
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
    controller.replaceText(
        10, 0, '//', const TextSelection.collapsed(offset: 12));

    final baseOffset = controller.selection.baseOffset;
    final plainText = controller.document.toPlainText();
    final start = baseOffset - timeShortcut.length;
    final typed = plainText.substring(start, start + timeShortcut.length);
    expect(typed, '//');

    final hour = DateTime.now().hour.toString().padLeft(2, '0');
    final minute = DateTime.now().minute.toString().padLeft(2, '0');
    final replacement = '$hour.$minute ';

    controller.replaceText(start, timeShortcut.length, replacement,
        TextSelection.collapsed(offset: start + replacement.length));
    controller.formatText(start, replacement.length, Attribute.bold);

    expect(
        controller.document
            .toPlainText()
            .startsWith('Log entry $hour.$minute '),
        isTrue);
  });
}
