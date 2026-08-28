import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Quill search highlighting formats text background', () {
    final doc = Document()..insert(0, 'Hello world, this is a test note about zoloft and health.');
    final controller = QuillController(
      document: doc,
      selection: const TextSelection(baseOffset: 0, extentOffset: 0),
    );

    final plainText = controller.document.toPlainText();
    const term = 'zoloft';
    final index = plainText.indexOf(term);
    expect(index, greaterThanOrEqualTo(0));

    const highlightAttr = BackgroundAttribute('#FFE082');
    controller.formatText(index, term.length, highlightAttr);

    final delta = controller.document.toDelta();
    expect(delta.toString().contains('#FFE082'), isTrue);
  });
}

