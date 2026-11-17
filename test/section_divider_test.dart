import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notel/note_page/note_text_toolbar.dart';
import 'package:notel/note_page/section_divider.dart';

void main() {
  testWidgets('toolbar inserts and renders a saved section divider',
      (tester) async {
    final document = Document()..insert(0, 'first second');
    final controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 6),
    );
    final focusNode = FocusNode();
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: QuillEditor(
                  focusNode: focusNode,
                  scrollController: scrollController,
                  configurations: QuillEditorConfigurations(
                    controller: controller,
                    embedBuilders: const [SectionDividerEmbedBuilder()],
                  ),
                ),
              ),
              NoteTextToolbar(controller: controller),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Insert divider'));
    await tester.pumpAndSettle();

    final savedDelta = controller.document.toDelta().toJson();
    expect(
      savedDelta.any(
        (operation) =>
            operation['insert'] is Map &&
            (operation['insert'] as Map).containsKey(
              SectionDividerEmbedBuilder.type,
            ),
      ),
      isTrue,
    );
    expect(controller.document.toPlainText(), contains('first'));
    expect(controller.document.toPlainText(), contains('second'));
    expect(find.byType(Divider), findsOneWidget);

    controller.document = Document.fromJson(savedDelta);
    await tester.pumpAndSettle();
    expect(find.byType(Divider), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focusNode.dispose();
    scrollController.dispose();
  });
}
