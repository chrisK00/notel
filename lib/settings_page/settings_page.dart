import 'dart:convert';
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

  final SettingsRepository _settingsRepository =
      SettingsRepository(Db.instance);

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
    await _settingsRepository.insertOrUpdate(
        _hideNoteSettings.id, _hideNoteSettings.toMap);
  }

  void exportNotes() async {
    final notes = await SettingsPageRepository.getNotes();
    final notesJson = jsonEncode(notes);
    Share.share(notesJson, subject: 'notes.json');
  }

// TODO
  void importNotes() {
// select file
// List<Map<String, dynamic>> decodedNotesJson = jsonDecode(notesJson);
// final notes = decodedJson.map((x) => Note.fromMap(x)).toList();
  }
}
