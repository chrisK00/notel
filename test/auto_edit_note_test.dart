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

  testWidgets('EditPage defaults to autofocus disabled for existing notes', (tester) async {
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
    expect(quillWidget.configurations.autoFocus, isFalse);
    expect(quillWidget.focusNode.hasFocus, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('Tapping on text in EditPage focuses editor and places cursor', (tester) async {
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
    expect(quillWidget.configurations.controller.selection.baseOffset, lessThan(7));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('EditPage with empty existing note enables autofocus', (tester) async {
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

  testWidgets('EditPage enables autofocus when autoEditExistingNotes setting is true', (tester) async {
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

  testWidgets('Tapping bottom empty area inserts newline and focuses editor', (tester) async {
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
      (widget) => widget is GestureDetector && widget.child is Container && (widget.child as Container).constraints?.minHeight == 120,
    );
    expect(bottomAreaFinder, findsOneWidget);

    await tester.tap(bottomAreaFinder);
    await tester.pump(const Duration(milliseconds: 50));

    final quillFinder = find.byType(QuillEditor);
    final quillWidget = tester.widget<QuillEditor>(quillFinder);
    expect(quillWidget.configurations.controller.document.toPlainText(), 'Line 1\nLine 2\n\n');
    expect(quillWidget.focusNode.hasFocus, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  test('Bottom-tap inserts newline when document does not end with blank line', () {
    final doc = Document.fromJson([
      {'insert': 'First line\nSecond line\n'}
    ]);
    final controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    final plainText = controller.document.toPlainText();
    expect(plainText.endsWith('\n\n'), isFalse);

    // Bottom-tap logic
    final insertPos = controller.document.length > 0 ? controller.document.length - 1 : 0;
    controller.replaceText(
      insertPos,
      0,
      '\n',
      TextSelection.collapsed(offset: insertPos + 1),
    );

    expect(controller.document.toPlainText(), 'First line\nSecond line\n\n');
    expect(controller.selection.baseOffset, controller.document.length - 1);
  });

  test('Bottom-tap moves to existing empty line when already ending in newline', () {
    final doc = Document.fromJson([
      {'insert': 'First line\n\n'}
    ]);
    final controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    final plainText = controller.document.toPlainText();
    expect(plainText.endsWith('\n\n'), isTrue);

    // Bottom-tap logic: do not insert extra newline
    controller.updateSelection(
      TextSelection.collapsed(offset: controller.document.length - 1),
      ChangeSource.local,
    );

    expect(controller.document.toPlainText(), 'First line\n\n');
    expect(controller.selection.baseOffset, controller.document.length - 1);
  });

  test('Bottom-tap on empty document moves cursor to position 0', () {
    final doc = Document();
    final controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    final plainText = controller.document.toPlainText();
    expect(plainText.trim().isEmpty, isTrue);

    controller.updateSelection(
      const TextSelection.collapsed(offset: 0),
      ChangeSource.local,
    );

    expect(controller.document.toPlainText(), '\n');
    expect(controller.selection.baseOffset, 0);
  });

  testWidgets('EditPage with initialNote displays title and content immediately on first pump', (tester) async {
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
    expect(quillWidget.configurations.controller.document.toPlainText(), contains('Line 1'));

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
