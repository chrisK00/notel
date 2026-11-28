import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/settings_repository.dart';
import 'package:notel/settings_page/settings_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE Settings(
            id TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
    Db.instance = db;
  });

  tearDownAll(() async {
    await db.close();
  });

  test('AppTheme.fromString parses correctly with dark as fallback', () {
    expect(AppTheme.fromString('dark'), AppTheme.dark);
    expect(AppTheme.fromString('black'), AppTheme.black);
    expect(AppTheme.fromString('light'), AppTheme.light);
    expect(AppTheme.fromString(null), AppTheme.dark);
    expect(AppTheme.fromString('unknown'), AppTheme.dark);
  });

  test('theme setting roundtrips via SettingsRepository', () async {
    final repo = SettingsRepository(Db.instance);

    await repo.insertOrUpdate(
      StringSettings.themeModeKey,
      () => StringSettings(StringSettings.themeModeKey, AppTheme.black.name).toMap(),
    );

    final blackSetting = await repo.getOrNull(
      StringSettings.themeModeKey,
      StringSettings.fromMap,
    );
    expect(blackSetting?.value, 'black');
    expect(AppTheme.fromString(blackSetting?.value), AppTheme.black);

    await repo.insertOrUpdate(
      StringSettings.themeModeKey,
      () => StringSettings(StringSettings.themeModeKey, AppTheme.light.name).toMap(),
    );

    final lightSetting = await repo.getOrNull(
      StringSettings.themeModeKey,
      StringSettings.fromMap,
    );
    expect(lightSetting?.value, 'light');
    expect(AppTheme.fromString(lightSetting?.value), AppTheme.light);
  });

  testWidgets('SettingsPage displays theme options and triggers callbacks',
      (tester) async {
    AppTheme currentTheme = AppTheme.dark;
    AppTheme? changedTheme;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => SettingsPage(
            appTheme: currentTheme,
            onAppThemeChanged: (theme) {
              setState(() => currentTheme = theme);
              changedTheme = theme;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Pure Black'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);

    await tester.tap(find.text('Pure Black'));
    await tester.pumpAndSettle();
    expect(changedTheme, AppTheme.black);
    expect(currentTheme, AppTheme.black);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(changedTheme, AppTheme.light);
    expect(currentTheme, AppTheme.light);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(changedTheme, AppTheme.dark);
    expect(currentTheme, AppTheme.dark);
  });
}
