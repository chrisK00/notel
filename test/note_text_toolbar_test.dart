import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notel/note_page/note_text_toolbar.dart';

void main() {
  testWidgets('insert URL adds a new link without detecting existing links',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = QuillController(
      document: Document.fromJson([
        {
          'insert': 'old',
          'attributes': {'link': 'https://old.example'},
        },
        {'insert': '\n'},
      ]),
      selection: const TextSelection.collapsed(offset: 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NoteTextToolbar(controller: controller)),
      ),
    );

    for (final tooltip in [
      'Insert URL',
      'Search',
      'Font size',
      'Text style',
      'Insert divider',
      'Copy formatted text',
      'Paste formatted text',
    ]) {
      expect(find.byTooltip(tooltip), findsOneWidget);
    }

    await tester.tap(find.byTooltip('Insert URL'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('link-text')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('link-url')))
          .controller!
          .text,
      isEmpty,
    );

    await tester.enterText(
      find.byKey(const ValueKey('link-text')),
      'new link',
    );
    await tester.enterText(
      find.byKey(const ValueKey('link-url')),
      'https://new.example',
    );
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(controller.document.toPlainText(), 'oldnew link\n');
    expect(
      controller.document
          .querySegmentLeafNode(0)
          .leaf
          ?.style
          .attributes[Attribute.link.key]
          ?.value,
      'https://old.example',
    );
    expect(
      controller.document
          .querySegmentLeafNode(3)
          .leaf
          ?.style
          .attributes[Attribute.link.key]
          ?.value,
      'https://new.example',
    );

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
