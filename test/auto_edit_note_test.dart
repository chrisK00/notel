import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notel/infrastructure/date_only.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/note.dart';
import 'package:notel/infrastructure/settings_repository.dart';
import 'package:notel/note_page/edit_page.dart';
import 'package:notel/note_page/new_note_page.dart';
import 'package:notel/notes_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE Note(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT,
            date TEXT,
            title TEXT,
            lastModified TEXT,
            categoryId INTEGER,
            hidden INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE Settings(
            id TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS Category(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');
      },
    );
    Db.instance = db;

    await db.insert('Note', {
      'id': 1,
      'title': 'Existing Note',
      'text': r'[{"insert":"Line 1\nLine 2\n"}]',
      'date': DateOnly.today().toString(),
      'lastModified': '2026-10-27 12:00:00.000',
      'categoryId': null,
    });
    await db.insert('Note', {
      'id': 2,
      'title': 'Empty Note',
      'text': '',
      'date': DateOnly.today().toString(),
      'lastModified': '2026-10-27 12:00:00.000',
      'categoryId': null,
    });
  });

  tearDown(() async {
    await db.close();
  });

  test('BoolSettings autoEditExistingNotes roundtrip', () {
    final setting = BoolSettings(BoolSettings.autoEditExistingNotesKey, true);
    final map = setting.toMap();
    final restored = BoolSettings.fromMap(map);
    expect(restored.id, BoolSettings.autoEditExistingNotesKey);
    expect(restored.value, isTrue);
  });

  testWidgets('NewNotePage defaults to autofocus enabled', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => NotesProvider(),
        child: const MaterialApp(
          home: NewNotePage(),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(milliseconds: 50));

    final quillFinder = find.byType(QuillEditor);
    expect(quillFinder, findsOneWidget);
    final quillWidget = tester.widget<QuillEditor>(quillFinder);
    expect(quillWidget.configurations.autoFocus, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('EditPage defaults to autofocus disabled for existing notes',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => NotesProvider(),
        child: const MaterialApp(
          home: EditPage(noteId: 1),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(milliseconds: 50));

    final quillFinder = find.byType(QuillEditor);
    expect(quillFinder, findsOneWidget);
    final quillWidget = tester.widget<QuillEditor>(quillFinder);
    expect(
      quillWidget.configurations.padding,
      const EdgeInsets.fromLTRB(16, 16, 16, 16),
    );
    final titlePadding = tester.widget<Padding>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('note-title')),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(titlePadding.padding, const EdgeInsets.fromLTRB(16, 4, 16, 0));
    expect(quillWidget.configurations.autoFocus, isFalse);
    expect(quillWidget.focusNode.hasFocus, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('Tapping on text in EditPage focuses editor and places cursor',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => NotesProvider(),
        child: const MaterialApp(
          home: EditPage(noteId: 1),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(milliseconds: 50));

    final quillFinder = find.byType(QuillEditor);
    final quillWidget = tester.widget<QuillEditor>(quillFinder);
    expect(quillWidget.focusNode.hasFocus, isFalse);

    // Tap on the first line text ("Line 1")
    final topLeft = tester.getTopLeft(quillFinder);
    await tester.tapAt(topLeft + const Offset(30, 25));
    await tester.pump(const Duration(milliseconds: 50));

    expect(quillWidget.focusNode.hasFocus, isTrue);
    expect(quillWidget.focusNode.canRequestFocus, isTrue);
    expect(quillWidget.configurations.controller.selection.isValid, isTrue);
    expect(quillWidget.configurations.controller.selection.isCollapsed, isTrue);
    expect(quillWidget.configurations.controller.selection.baseOffset,
        lessThan(7));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('EditPage with empty existing note enables autofocus',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => NotesProvider(),
        child: const MaterialApp(
          home: EditPage(noteId: 2),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(milliseconds: 50));

    final quillFinder = find.byType(QuillEditor);
    expect(quillFinder, findsOneWidget);
    final quillWidget = tester.widget<QuillEditor>(quillFinder);
    expect(quillWidget.configurations.autoFocus, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets(
      'EditPage enables autofocus when autoEditExistingNotes setting is true',
      (tester) async {
    await tester.runAsync(() async {
      await SettingsRepository(db).insertOrUpdate(
        BoolSettings.autoEditExistingNotesKey,
        BoolSettings(BoolSettings.autoEditExistingNotesKey, true).toMap,
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => NotesProvider(),
        child: const MaterialApp(
          home: EditPage(noteId: 1),
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 50));

    final quillFinder = find.byType(QuillEditor);
    expect(quillFinder, findsOneWidget);
    final quillWidget = tester.widget<QuillEditor>(quillFinder);
    expect(quillWidget.configurations.autoFocus, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets(
      'Tapping bottom empty area adds a blank line without marking note changed',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => NotesProvider(),
        child: const MaterialApp(
          home: EditPage(noteId: 1),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(milliseconds: 50));

    // Tap bottom empty area below QuillEditor
    final bottomAreaFinder = find.byWidgetPredicate(
      (widget) =>
          widget is GestureDetector &&
          widget.child is Container &&
          (widget.child as Container).constraints?.minHeight == 120,
    );
    expect(bottomAreaFinder, findsOneWidget);

    await tester.tap(bottomAreaFinder);
    await tester.pump(const Duration(milliseconds: 50));

    final quillFinder = find.byType(QuillEditor);
    final quillWidget = tester.widget<QuillEditor>(quillFinder);
    expect(quillWidget.configurations.controller.document.toPlainText(),
        'Line 1\nLine 2\n\n');
    expect(
      quillWidget.configurations.controller.selection.baseOffset,
      quillWidget.configurations.controller.document.length - 1,
    );
    expect(quillWidget.focusNode.hasFocus, isTrue);
    final saveButtonOpacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byIcon(Icons.save),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(saveButtonOpacity.opacity, 0);

    final controller = quillWidget.configurations.controller;
    final insertPos = controller.selection.baseOffset;
    controller.replaceText(
      insertPos,
      0,
      'New text',
      TextSelection.collapsed(offset: insertPos + 'New text'.length),
    );
    await tester.pump();

    final changedSaveButtonOpacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byIcon(Icons.save),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(changedSaveButtonOpacity.opacity, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets(
      'EditPage with initialNote displays title and content immediately on first pump',
      (tester) async {
    final testNote = Note(
      id: 1,
      title: 'Existing Note',
      displayText: r'[{"insert":"Line 1\nLine 2\n"}]',
      date: DateOnly.today(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => NotesProvider(),
        child: MaterialApp(
          home: EditPage(noteId: 1, initialNote: testNote),
        ),
      ),
    );

    // On the very first frame, title and editor content are already visible without awaiting db
    expect(find.text('Existing Note'), findsOneWidget);
    final quillFinder = find.byType(QuillEditor);
    expect(quillFinder, findsOneWidget);
    final quillWidget = tester.widget<QuillEditor>(quillFinder);
    expect(quillWidget.configurations.controller.document.toPlainText(),
        contains('Line 1'));

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
