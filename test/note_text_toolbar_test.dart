import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notel/note_page/exercise_embed.dart';
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
        home:
            Scaffold(body: NoteTextToolbar(controller: controller, noteId: 1)),
      ),
    );

    for (final tooltip in [
      'Insert URL',
      'Search',
      'Font size',
      'Text style',
      'Insert divider',
      'Insert exercise',
      'Comments',
      'Copy formatted text',
      'Paste formatted text',
    ]) {
      expect(find.byTooltip(tooltip), findsOneWidget);
    }
    expect(find.byIcon(Icons.format_indent_increase), findsOneWidget);
    expect(find.byIcon(Icons.format_indent_decrease), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsOneWidget);

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

  testWidgets('insert exercise stores its details as a document embed',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home:
            Scaffold(body: NoteTextToolbar(controller: controller, noteId: 1)),
      ),
    );

    await tester.tap(find.byTooltip('Insert exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('exercise-name')), 'Squat');
    await tester.enterText(find.byKey(const ValueKey('exercise-sets')), '3');
    await tester.enterText(find.byKey(const ValueKey('exercise-reps')), '8');
    await tester.enterText(
        find.byKey(const ValueKey('exercise-weight')), '40 kg');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final embed = controller.document
        .toDelta()
        .toJson()
        .map((operation) => operation['insert'])
        .whereType<Map>()
        .single;
    expect(
      jsonDecode(embed[ExerciseEmbedBuilder.type] as String),
      {
        'name': 'Squat',
        'sets': '3',
        'reps': '8',
        'weight': '40 kg',
        'notes': '',
      },
    );

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('exercise embed expands and can be edited', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = QuillController(
      document: Document.fromJson([
        {
          'insert': {
            ExerciseEmbedBuilder.type: jsonEncode({
              'name': 'Squat',
              'sets': '3',
              'reps': '8',
              'weight': '40 kg',
              'notes': '',
            }),
          },
        },
        {'insert': '\n'},
      ]),
      selection: const TextSelection.collapsed(offset: 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuillEditor.basic(
            configurations: QuillEditorConfigurations(
              controller: controller,
              embedBuilders: const [ExerciseEmbedBuilder()],
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Squat'), findsOneWidget);
    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();
    expect(find.text('3 sets × 8 reps'), findsOneWidget);
    expect(find.text('Weight: 40 kg'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('exercise-name')), 'Front squat');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final embed = controller.document
        .toDelta()
        .toJson()
        .map((operation) => operation['insert'])
        .whereType<Map>()
        .single;
    expect(
      jsonDecode(embed[ExerciseEmbedBuilder.type] as String)['name'],
      'Front squat',
    );

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('checklist can be indented from the main toolbar',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = QuillController(
      document: Document.fromJson([
        {'insert': 'Todo\n'},
      ]),
      selection: const TextSelection.collapsed(offset: 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home:
            Scaffold(body: NoteTextToolbar(controller: controller, noteId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_box));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.format_indent_increase));
    await tester.pump();

    final attributes =
        controller.document.toDelta().toJson().last['attributes'] as Map;
    expect(attributes[Attribute.list.key], Attribute.unchecked.value);
    expect(attributes[Attribute.indent.key], 1);

    await tester.tap(find.byIcon(Icons.format_indent_decrease));
    await tester.pump();
    final updatedAttributes =
        controller.document.toDelta().toJson().last['attributes'] as Map;
    expect(updatedAttributes.containsKey(Attribute.indent.key), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    controller.dispose();
  });
}
