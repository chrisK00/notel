import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:notel/db.dart';
import 'package:share_plus/share_plus.dart';

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
    // TODO add encryption
    final notes = await Db.instance.query(Db.noteTable);
    final notesJson = jsonEncode(notes);
    Share.share(notesJson, subject: 'notes.json');
  }

// todo
// maybe add store in gdrive support if safe without backend?
  void importNotes() {
// select file
// List<Map<String, dynamic>> decodedNotesJson = jsonDecode(notesJson);
// final notes = decodedJson.map((x) => Note.fromMap(x)).toList();
  }
}
