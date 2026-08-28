import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:notel/infrastructure/auto_backup_service.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/settings_repository.dart';
import 'package:notel/utils/simple_encryptor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'settings_page_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<StatefulWidget> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  var _hideNoteSettings = BoolSettings(BoolSettings.hideNoteTextKey, false);
  bool _autoBackupEnabled = false;
  String _autoBackupDirectory = "";
  String _autoBackupPassword = "";
  String? _autoBackupLastDate;
  String _timeShortcut = "..";
  String _message = "";

  final SettingsRepository _settingsRepository = SettingsRepository(Db.instance);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final hideSettings = await _settingsRepository.getOrNull(
      BoolSettings.hideNoteTextKey,
      BoolSettings.fromMap,
    );
    final autoEnabled = await _settingsRepository.getOrNull(
      BoolSettings.autoBackupEnabledKey,
      BoolSettings.fromMap,
    );
    final autoDir = await _settingsRepository.getOrNull(
      StringSettings.autoBackupDirectoryKey,
      StringSettings.fromMap,
    );
    final autoPass = await _settingsRepository.getOrNull(
      StringSettings.autoBackupPasswordKey,
      StringSettings.fromMap,
    );
    final autoDate = await _settingsRepository.getOrNull(
      StringSettings.autoBackupLastDateKey,
      StringSettings.fromMap,
    );
    final timeShortcut = await _settingsRepository.getOrNull(
      StringSettings.timeShortcutKey,
      StringSettings.fromMap,
    );

    if (!mounted) return;
    setState(() {
      if (hideSettings != null) _hideNoteSettings = hideSettings;
      _autoBackupEnabled = autoEnabled?.value ?? false;
      _autoBackupDirectory = autoDir?.value ?? "";
      _autoBackupPassword = autoPass?.value ?? "";
      _autoBackupLastDate = autoDate?.value;
      _timeShortcut = timeShortcut?.value ?? "..";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _message,
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                ),
              ),
            ),

          // --- Manual Backup / Restore Section ---
          const Text('Manual Backup & Restore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Export Notes & Categories'),
                  subtitle: const Text('Save an encrypted backup file (.bin) to share or keep'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: exportNotes,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Import Backup'),
                  subtitle: const Text('Restore notes and categories from an encrypted backup file'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: importNotes,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- Automated Weekly Backup Section ---
          const Text('Automated Backup (Weekly)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.backup),
                  title: const Text('Enable Weekly Auto-Backup'),
                  subtitle: Text(_autoBackupEnabled
                      ? (_autoBackupLastDate != null
                          ? 'Last backup: ${_formatLastBackupDate(_autoBackupLastDate!)}'
                          : 'Ready — backs up automatically every 7 days')
                      : 'Disabled'),
                  value: _autoBackupEnabled,
                  onChanged: _toggleAutoBackup,
                ),
                if (_autoBackupEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.folder_open),
                    title: const Text('Backup Folder'),
                    subtitle: Text(
                      _autoBackupDirectory.isEmpty ? 'No folder selected (required)' : _autoBackupDirectory,
                      style: TextStyle(
                        color: _autoBackupDirectory.isEmpty ? Colors.red : null,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: _pickAutoBackupFolder,
                      child: Text(_autoBackupDirectory.isEmpty ? 'Select' : 'Change'),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Encryption Password'),
                    subtitle: Text(
                      _autoBackupPassword.isEmpty
                          ? 'No password set (required)'
                          : '•••••••• (${_autoBackupPassword.length} chars)',
                      style: TextStyle(
                        color: _autoBackupPassword.isEmpty ? Colors.red : null,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: _changeAutoBackupPassword,
                      child: Text(_autoBackupPassword.isEmpty ? 'Set' : 'Change'),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Backup Now'),
                          onPressed: (_autoBackupDirectory.isEmpty || _autoBackupPassword.isEmpty)
                              ? null
                              : _runManualAutoBackupNow,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // --- Cloud Sync Guide ---
          const ExpansionTile(
            leading: Icon(Icons.cloud_sync, color: Colors.deepPurple),
            title: Text('How to sync with Google Drive / Cloud'),
            childrenPadding: EdgeInsets.all(16),
            children: [
              Text(
                '1. In Auto-Backup above, set your password and select a folder on your device (e.g. Documents/NotelBackups).\n\n'
                '2. To sync with Google Drive / OneDrive / Nextcloud:\n'
                '   • On PC: Choose a folder located inside your Google Drive or OneDrive sync directory.\n'
                '   • On Android: Use the Google Drive app (or free sync apps like Autosync for Google Drive or Syncthing) to automatically sync your chosen folder.\n\n'
                '3. Notel will silently create an encrypted backup (.enc) in that folder weekly. Your cloud service will upload it automatically in the background.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- General App Settings ---
          const Text('Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_off),
                  title: const Text('Hide Note Text Preview'),
                  subtitle: const Text('Only show note titles and dates on the home screen'),
                  value: _hideNoteSettings.value,
                  onChanged: toggleHideNoteText,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- Editor Shortcuts ---
          const Text('Editor Shortcuts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Insert Current Time'),
              subtitle: Text(_timeShortcut.isEmpty
                  ? 'Disabled (tap to configure)'
                  : 'Type "$_timeShortcut" in note editor to insert timestamp'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _timeShortcut.isEmpty ? 'Off' : _timeShortcut,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit_outlined, size: 18),
                ],
              ),
              onTap: _editTimeShortcut,
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _editTimeShortcut() async {
    final textController = TextEditingController(text: _timeShortcut);
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Insert Time Shortcut'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the characters typed in the note editor to instantly insert the current timestamp (e.g. 14.30).\n\nLeave blank to disable.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Shortcut sequence',
                  hintText: 'e.g. .. or // or ::',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, textController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _settingsRepository.insertOrUpdate(
        StringSettings.timeShortcutKey,
        () => StringSettings(StringSettings.timeShortcutKey, result).toMap(),
      );
      setState(() => _timeShortcut = result);
    }
  }

  String _formatLastBackupDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('d MMM yyyy, HH:mm').format(date);
    } catch (_) {
      return isoString;
    }
  }

  Future<void> _toggleAutoBackup(bool enabled) async {
    setState(() => _autoBackupEnabled = enabled);
    await _settingsRepository.insertOrUpdate(
      BoolSettings.autoBackupEnabledKey,
      BoolSettings(BoolSettings.autoBackupEnabledKey, enabled).toMap,
    );

    if (enabled) {
      if (_autoBackupDirectory.isEmpty) {
        await _pickAutoBackupFolder();
      }
      if (_autoBackupPassword.isEmpty && mounted) {
        await _changeAutoBackupPassword();
      }
    }
  }

  Future<void> _pickAutoBackupFolder() async {
    final selectedDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Auto-Backup Folder',
    );
    if (selectedDir != null && selectedDir.trim().isNotEmpty) {
      setState(() => _autoBackupDirectory = selectedDir.trim());
      await _settingsRepository.insertOrUpdate(
        StringSettings.autoBackupDirectoryKey,
        StringSettings(StringSettings.autoBackupDirectoryKey, selectedDir.trim()).toMap,
      );
      setState(() => _message = 'Backup folder set');
    }
  }

  Future<void> _changeAutoBackupPassword() async {
    final newPass = await _promptForEncryptionKey(
      title: 'Set Auto-Backup Password',
      hint: 'Password for encrypted backups',
    );
    if (newPass != null && newPass.isNotEmpty) {
      setState(() => _autoBackupPassword = newPass);
      await _settingsRepository.insertOrUpdate(
        StringSettings.autoBackupPasswordKey,
        StringSettings(StringSettings.autoBackupPasswordKey, newPass).toMap,
      );
      setState(() => _message = 'Auto-backup password saved');
    }
  }

  Future<void> _runManualAutoBackupNow() async {
    setState(() => _message = 'Running backup...');
    final file = await AutoBackupService.performAutoBackup(repo: _settingsRepository);
    if (!mounted) return;
    if (file != null) {
      final now = DateTime.now().toIso8601String();
      setState(() {
        _autoBackupLastDate = now;
        _message = 'Backup created: ${file.path.split(Platform.pathSeparator).last}';
      });
    } else {
      setState(() => _message = 'Failed to create backup. Check folder and password.');
    }
  }

  Future<String?> _promptForEncryptionKey({
    String title = "Backup password",
    String hint = "Enter password",
  }) async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> toggleHideNoteText(bool newSettings) async {
    setState(() => _hideNoteSettings.value = newSettings);
    await _settingsRepository.insertOrUpdate(_hideNoteSettings.id, _hideNoteSettings.toMap);
  }

  Future<void> exportNotes() async {
    try {
      final encryptionKey = await _promptForEncryptionKey();
      if (encryptionKey == null || encryptionKey.isEmpty) return;

      final backupPayload = await SettingsPageRepository.createBackupPayload();
      final encrypted = SimpleEncryptor.encode(jsonEncode(backupPayload), encryptionKey);

      final targetDir = await getTemporaryDirectory();
      final fileName = 'notel_backup_${DateFormat('yyyyMMdd').format(DateTime.now())}.bin';
      final filePath = '${targetDir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsString(encrypted);

      final result = await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
      );

      if (result.status == ShareResultStatus.success) {
        setState(() => _message = 'Export complete');
        await _settingsRepository.insertOrUpdate(
          StringSettings.lastExportReminderKey,
          StringSettings(StringSettings.lastExportReminderKey, DateTime.now().toString()).toMap,
        );
      } else {
        setState(() => _message = '${result.status}: ${result.raw}');
      }

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      setState(() => _message = 'Error: ${e.toString()}');
    }
  }

  Future<void> importNotes() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.single.path == null) return;

      final encryptionKey = await _promptForEncryptionKey();
      if (encryptionKey == null || encryptionKey.isEmpty) return;

      final file = File(result.files.single.path!);
      final fileContent = await file.readAsString();

      final decryptedJson = SimpleEncryptor.decrypt(fileContent, encryptionKey);
      final dynamic decoded = jsonDecode(decryptedJson);

      await SettingsPageRepository.restoreBackupPayload(decoded);

      setState(() => _message = 'Import complete');
    } catch (e) {
      if (e.toString().contains('integrity') || e.toString().contains('padding')) {
        setState(() => _message = 'Wrong encryption key!');
      } else {
        setState(() => _message = 'Error: ${e.toString()}');
      }
    }
  }
}
