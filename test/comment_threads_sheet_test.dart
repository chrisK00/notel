import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/note_page/comment_threads_sheet.dart';
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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE NoteComment(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            noteId INTEGER NOT NULL,
            parentId INTEGER,
            quotedText TEXT NOT NULL,
            startOffset INTEGER NOT NULL,
            endOffset INTEGER NOT NULL,
            body TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
    Db.instance = db;
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('selection comment creates a thread and supports replies',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = QuillController(
      document: Document.fromJson([
        {'insert': 'Bench press\n'},
      ]),
      selection: const TextSelection(baseOffset: 0, extentOffset: 11),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommentThreadsSheet(
            noteId: 7,
            quotedText: controller.document.getPlainText(0, 11),
            startOffset: 0,
            endOffset: 11,
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Comment on “Bench press”'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('new-comment')),
      'Try close grip instead.',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Post comment'));
    await tester.pump();
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.text('“Bench press”'), findsOneWidget);
    expect(find.text('Try close grip instead.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reply-to-comment')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const ValueKey('comment-reply')),
      'I will test it next session.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send-comment-reply')));
    await tester.pump();
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    await tester.pump();
    expect(find.text('I will test it next session.'), findsOneWidget);

    final comments = await tester.runAsync(
      () => db.query('NoteComment', orderBy: 'id ASC'),
    );
    final rows = comments!;
    expect(rows, hasLength(2));
    expect(rows.first['quotedText'], 'Bench press');
    expect(rows.last['parentId'], rows.first['id']);
    expect(rows.first['startOffset'], 0);
    expect(rows.first['endOffset'], 11);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
