import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/settings_repository.dart';
import 'package:share_plus/share_plus.dart';

import 'settings_page_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<StatefulWidget> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  var _hideNoteSettings = BoolSettings(BoolSettings.hideNoteTextKey, false);
  var _message = "";

  final SettingsRepository _settingsRepository = SettingsRepository(Db.instance);

  @override
  void initState() {
    _settingsRepository
        .get(BoolSettings.hideNoteTextKey, BoolSettings.fromMap)
        .then((settings) => {setState(() => _hideNoteSettings = settings)});
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Text(_message),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Text('Export Notes'),
              ElevatedButton(
                  onPressed: exportNotes,
                  child: const Icon(
                    Icons.save_alt,
                  ))
            ],
          ),
          const SizedBox(
            height: 10,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Text('Import Notes'),
              ElevatedButton(
                  onPressed: importNotes,
                  child: const Icon(
                    Icons.input,
                  )),
            ],
          ),
          const SizedBox(
            height: 10,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Text('Hide Note Text'),
              Switch(
                value: _hideNoteSettings.value,
                onChanged: toggleHideNoteText,
              )
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Editor Shortcuts",
                textScaler: TextScaler.linear(1.5),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Insert Time:  "),
                  Text("..",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      )),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  void showToast(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: const Text("Changes saved. Restart to apply"),
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'Dismiss',
        onPressed: () {},
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> toggleHideNoteText(bool newSettings) async {
    setState(() => _hideNoteSettings.value = newSettings);
    await _settingsRepository.insertOrUpdate(_hideNoteSettings.id, _hideNoteSettings.toMap);
  }

  Future<void> exportNotes() async {
    try {
      final notes = await SettingsPageRepository.getNotes();
      setState(() => _message = "fetched ${notes.length} notes");

      final notesJson = jsonEncode(notes);
      setState(() => _message = "json encoded notes");

      var result = await Share.share(notesJson, subject: 'notes.json');
      setState(() => _message = "${result.status}: ${result.raw}");
    } catch (e) {
      setState(() => _message = e.toString());
    }
  }

  Future<void> importNotes() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final fileContent = await file.readAsString();
      final List<dynamic> notesDynamicJson = jsonDecode(fileContent);

      final List<Map<String, Object?>> notesJson =
          notesDynamicJson.map<Map<String, Object?>>((e) => Map<String, Object?>.from(e)).toList();

      if (notesJson.isEmpty) {
        _message = 'Found 0 notes to import';
        return;
      }

      await SettingsPageRepository.insertNotes(notesJson);

      _message = '';
    } catch (e) {
      setState(() => _message = e.toString());
    }
  }
}
