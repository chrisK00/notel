import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notel/infrastructure/date_only.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/settings_repository.dart';
import 'package:notel/main.dart';
import 'package:notel/note_page/edit_page.dart';
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
      'title': 'Test Note',
      'text': r'[{"insert":"Hello\n"}]',
      'date': DateOnly.today().toString(),
      'lastModified': '2026-11-28 12:00:00.000',
      'categoryId': null,
    });
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('records active note ID when EditPage opens', (tester) async {
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

    String? activeNoteId;
    await tester.runAsync(() async {
      final repo = SettingsRepository(Db.instance);
      final activeSetting = await repo.getOrNull(
        StringSettings.activeNoteIdKey,
        StringSettings.fromMap,
      );
      activeNoteId = activeSetting?.value;
    });

    expect(activeNoteId, '1');
  });

  testWidgets(
      'auto-saves unsaved changes when app becomes inactive/backgrounded',
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

    // Type a title
    await tester.enterText(find.byType(TextField).first, 'Auto-Saved Title');
    await tester.pump(const Duration(milliseconds: 50));

    // Simulate switching app (inactive lifecycle)
    await tester.runAsync(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 50));

    // Verify DB updated
    List<Map<String, Object?>>? rows;
    await tester.runAsync(() async {
      rows = await Db.instance.query(
        'Note',
        where: 'id = ?',
        whereArgs: [1],
      );
    });
    expect(rows!.first['title'], 'Auto-Saved Title');
  });

  testWidgets('App restores active note on launch if activeNoteIdKey set',
      (tester) async {
    await tester.runAsync(() async {
      final repo = SettingsRepository(Db.instance);
      await repo.insertOrUpdate(
        StringSettings.activeNoteIdKey,
        () => StringSettings(StringSettings.activeNoteIdKey, '1').toMap(),
      );
    });

    final notesProvider = NotesProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<NotesProvider>.value(
        value: notesProvider,
        child: const App(),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.byType(EditPage), findsOneWidget);
    expect(find.text('Test Note'), findsOneWidget);
  });
}
