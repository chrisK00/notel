import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:notel/infrastructure/auto_backup_service.dart';
import 'package:notel/infrastructure/category_repository.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/settings_repository.dart';
import 'package:notel/note_page/note_page_repository.dart';
import 'package:notel/utils/simple_encryptor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late SettingsRepository settingsRepo;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('notel_auto_backup_test_');
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 5,
      onCreate: (db, version) async {
        await db.execute("CREATE TABLE Note(id INTEGER PRIMARY KEY, text TEXT, date TEXT, title TEXT, lastModified TEXT, categoryId INTEGER, hidden INTEGER NOT NULL DEFAULT 0)");
        await db.execute("CREATE TABLE Settings(id TEXT PRIMARY KEY, value TEXT)");
        await db.execute("CREATE TABLE Category(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)");
      },
    );
    Db.instance = db;
    settingsRepo = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('AutoBackupService should not run if disabled', () async {
    final shouldRun = await AutoBackupService.shouldPerformAutoBackup(settingsRepo);
    expect(shouldRun, isFalse);
  });

  test('AutoBackupService should run when enabled with folder and password', () async {
    await settingsRepo.insertOrUpdate(
      BoolSettings.autoBackupEnabledKey,
      BoolSettings(BoolSettings.autoBackupEnabledKey, true).toMap,
    );
    await settingsRepo.insertOrUpdate(
      StringSettings.autoBackupDirectoryKey,
      StringSettings(StringSettings.autoBackupDirectoryKey, tempDir.path).toMap,
    );
    await settingsRepo.insertOrUpdate(
      StringSettings.autoBackupPasswordKey,
      StringSettings(StringSettings.autoBackupPasswordKey, 'secret123').toMap,
    );

    final shouldRun = await AutoBackupService.shouldPerformAutoBackup(settingsRepo);
    expect(shouldRun, isTrue);

    // Create test category and note
    final cat = await CategoryRepository.create('Health');
    await NotePageRepository.createNote(categoryId: cat.id);

    // Perform backup
    final backupFile = await AutoBackupService.performAutoBackup(repo: settingsRepo);
    expect(backupFile, isNotNull);
    expect(await backupFile!.exists(), isTrue);

    // Verify latest snapshot was also created
    final latestFile = File('${tempDir.path}${Platform.pathSeparator}notel_backup_latest.enc');
    expect(await latestFile.exists(), isTrue);

    // Verify content can be decrypted
    final encryptedContent = await backupFile.readAsString();
    final decrypted = SimpleEncryptor.decrypt(encryptedContent, 'secret123');
    final Map<String, dynamic> payload = jsonDecode(decrypted);

    expect(payload['version'], 1);
    expect((payload['categories'] as List).length, 1);
    expect((payload['notes'] as List).length, 1);

    // Now shouldPerformAutoBackup should be false (since backup just ran)
    final shouldRunAgain = await AutoBackupService.shouldPerformAutoBackup(settingsRepo);
    expect(shouldRunAgain, isFalse);
  });

  test('AutoBackupService retains max 2 dated backups', () async {
    await settingsRepo.insertOrUpdate(
      BoolSettings.autoBackupEnabledKey,
      BoolSettings(BoolSettings.autoBackupEnabledKey, true).toMap,
    );
    await settingsRepo.insertOrUpdate(
      StringSettings.autoBackupDirectoryKey,
      StringSettings(StringSettings.autoBackupDirectoryKey, tempDir.path).toMap,
    );
    await settingsRepo.insertOrUpdate(
      StringSettings.autoBackupPasswordKey,
      StringSettings(StringSettings.autoBackupPasswordKey, 'pass').toMap,
    );

    // Create 3 fake older backup files
    final old1 = File('${tempDir.path}${Platform.pathSeparator}notel_backup_20260101.enc');
    final old2 = File('${tempDir.path}${Platform.pathSeparator}notel_backup_20260108.enc');
    final old3 = File('${tempDir.path}${Platform.pathSeparator}notel_backup_20260115.enc');
    await old1.writeAsString('1');
    await old2.writeAsString('2');
    await old3.writeAsString('3');

    await AutoBackupService.performAutoBackup(repo: settingsRepo);

    // Should keep 2 most recent dated backups + latest.enc
    final files = tempDir.listSync().map((e) => e.path.split(Platform.pathSeparator).last).toList();
    expect(files.contains('notel_backup_20260101.enc'), isFalse);
    expect(files.contains('notel_backup_20260108.enc'), isFalse);
    expect(files.contains('notel_backup_20260115.enc'), isTrue);
    expect(files.contains('notel_backup_latest.enc'), isTrue);
  });
}
