import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'settings_page_repository.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 30),
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
        ],
      ),
    );
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
