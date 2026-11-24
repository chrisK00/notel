import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notel/activity_log/activity_calendar_page.dart';
import 'package:notel/infrastructure/db.dart';
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
          CREATE TABLE Note(
            id INTEGER PRIMARY KEY,
            text TEXT,
            date TEXT,
            lastModified TEXT,
            title TEXT,
            categoryId INTEGER,
            hidden INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    Db.instance = db;
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('calendar marker is visible and month-year opens picker',
      (tester) async {
    tester.view.physicalSize = const Size(411, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    await tester.runAsync(() async {
      await db.insert('Note', {
        'text': '08:00 start walk\n',
        'date': _dateString(now),
      });
    });

    await tester.pumpWidget(
      const MaterialApp(home: ActivityCalendarPage()),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();

    const monthNames = [
      'januari',
      'februari',
      'mars',
      'april',
      'maj',
      'juni',
      'juli',
      'augusti',
      'september',
      'oktober',
      'november',
      'december',
    ];
    final currentMonthTitle = '${monthNames[now.month - 1]} ${now.year}';
    final marker = find.byKey(
      ValueKey('activity-marker-${now.year}-${now.month}-${now.day}'),
    );
    expect(marker, findsOneWidget);
    expect(tester.getSize(marker), const Size(13, 13));
    expect(find.text('Föregående'), findsOneWidget);
    expect(find.text('Nästa'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Föregående'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Nästa'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text(currentMonthTitle));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('previous and next buttons move between filtered days',
      (tester) async {
    tester.view.physicalSize = const Size(411, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now();
    await tester.runAsync(() async {
      for (final entry in [
        (today.subtract(const Duration(days: 2)), 'swim'),
        (today, 'walk'),
        (today.add(const Duration(days: 2)), 'sleep'),
      ]) {
        await db.insert('Note', {
          'text': '08:00 start ${entry.$2}\n',
          'date': _dateString(entry.$1),
        });
      }
    });

    await tester.pumpWidget(
      const MaterialApp(home: ActivityCalendarPage()),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 's');
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Föregående'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Nästa'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Nästa'));
    await tester.pump();
    expect(find.text('sleep'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Nästa'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Föregående'));
    await tester.pump();
    expect(find.text('swim'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Föregående'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });
}

String _dateString(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
