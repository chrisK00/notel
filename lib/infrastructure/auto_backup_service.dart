import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/settings_repository.dart';
import 'package:notel/settings_page/settings_page_repository.dart';
import 'package:notel/utils/simple_encryptor.dart';

class AutoBackupService {
  static const int backupIntervalDays = 7; // Weekly auto-backup
  static const int maxDatedBackups = 2; // Keep 2 most recent dated backups

  static Future<bool> shouldPerformAutoBackup(SettingsRepository settingsRepo) async {
    final enabledSetting = await settingsRepo.getOrNull(
      BoolSettings.autoBackupEnabledKey,
      BoolSettings.fromMap,
    );
    if (enabledSetting == null || !enabledSetting.value) return false;

    final dirSetting = await settingsRepo.getOrNull(
      StringSettings.autoBackupDirectoryKey,
      StringSettings.fromMap,
    );
    if (dirSetting == null || dirSetting.value.trim().isEmpty) return false;

    final passSetting = await settingsRepo.getOrNull(
      StringSettings.autoBackupPasswordKey,
      StringSettings.fromMap,
    );
    if (passSetting == null || passSetting.value.isEmpty) return false;

    final lastDateSetting = await settingsRepo.getOrNull(
      StringSettings.autoBackupLastDateKey,
      StringSettings.fromMap,
    );
    if (lastDateSetting == null || lastDateSetting.value.isEmpty) return true;

    final lastDate = DateTime.tryParse(lastDateSetting.value);
    if (lastDate == null) return true;

    return DateTime.now().difference(lastDate).inDays >= backupIntervalDays;
  }

  static Future<File?> performAutoBackup({SettingsRepository? repo}) async {
    final settingsRepo = repo ?? SettingsRepository(Db.instance);

    final dirSetting = await settingsRepo.getOrNull(
      StringSettings.autoBackupDirectoryKey,
      StringSettings.fromMap,
    );
    final passSetting = await settingsRepo.getOrNull(
      StringSettings.autoBackupPasswordKey,
      StringSettings.fromMap,
    );

    if (dirSetting == null ||
        dirSetting.value.trim().isEmpty ||
        passSetting == null ||
        passSetting.value.isEmpty) {
      return null;
    }

    final targetDir = Directory(dirSetting.value);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final backupPayload = await SettingsPageRepository.createBackupPayload();
    final jsonString = jsonEncode(backupPayload);
    final encrypted = await SimpleEncryptor.encodeAsync(jsonString, passSetting.value);

    final fileName = 'notel_backup_${DateFormat('yyyyMMdd').format(DateTime.now())}.enc';
    final backupFile = File('${targetDir.path}${Platform.pathSeparator}$fileName');
    await backupFile.writeAsString(encrypted);

    // Also write a latest snapshot for quick access
    final latestFile = File('${targetDir.path}${Platform.pathSeparator}notel_backup_latest.enc');
    await latestFile.writeAsString(encrypted);

    // Cleanup older dated backup files, keeping the 2 most recent
    await _rotateOldBackups(targetDir);

    await settingsRepo.insertOrUpdate(
      StringSettings.autoBackupLastDateKey,
      StringSettings(StringSettings.autoBackupLastDateKey, DateTime.now().toIso8601String()).toMap,
    );

    return backupFile;
  }

  static Future<void> _rotateOldBackups(Directory targetDir) async {
    try {
      final datedBackupPattern = RegExp(r'^notel_backup_\d{8}(_\d+)?\.enc$');
      final entities = await targetDir.list().toList();
      final backupFiles = entities
          .whereType<File>()
          .where((f) => datedBackupPattern.hasMatch(f.path.split(Platform.pathSeparator).last))
          .toList();

      if (backupFiles.length > maxDatedBackups) {
        // Sort by filename descending (date is in yyyyMMdd format)
        backupFiles.sort((a, b) => b.path.compareTo(a.path));

        for (int i = maxDatedBackups; i < backupFiles.length; i++) {
          try {
            await backupFiles[i].delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  static Future<void> checkAndRun({SettingsRepository? repo}) async {
    try {
      final settingsRepo = repo ?? SettingsRepository(Db.instance);
      if (await shouldPerformAutoBackup(settingsRepo)) {
        await performAutoBackup(repo: settingsRepo);
      }
    } catch (_) {
      // Auto-backup is non-blocking and silent
    }
  }
}
