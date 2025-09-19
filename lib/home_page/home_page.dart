import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:notel/console.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/settings_repository.dart';
import 'package:notel/note_page/new_note_page.dart';
import 'package:notel/utils/extensions.dart';
import 'package:provider/provider.dart';

import '../note_page/edit_page.dart';
import '../infrastructure/note.dart';
import '../notes_provider.dart';
import 'home_page_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchTextController = TextEditingController();
  final _settingsRepository = SettingsRepository(Db.instance);
  var _hideNoteTextSettings = BoolSettings(BoolSettings.hideNoteTextKey, true);

  Future<void> loadNotes() async {
    final loadedNotes = await HomePageRepository.loadNotes();
    final provider = Provider.of<NotesProvider>(context, listen: false);
    provider.init(loadedNotes);
  }

  Future<void> loadSettings() async {
    final settings = await _settingsRepository.get(BoolSettings.hideNoteTextKey, BoolSettings.fromMap);
    setState(() {
      _hideNoteTextSettings = settings;
    });
  }

  @override
  void initState() {
    loadSettings();
    super.initState();
    loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(builder: (context, provider, child) {
      return Scaffold(
        body: Container(
          margin: const EdgeInsets.only(top: 60),
          child: Column(children: [
            Container(child: searchBar(provider)),
            Expanded(
              child: ListView.separated(
                  key: const PageStorageKey('notesListKey'),
                  itemBuilder: (context, index) => noteRow(context, provider.notes[index]),
                  separatorBuilder: (_, __) => const Divider(),
                  itemCount: provider.notes.length),
            ),
          ]),
        ),
        floatingActionButton: addNoteButton(context),
      );
    });
  }

  Widget searchBar(NotesProvider provider) {
    return TextField(
      controller: _searchTextController,
      decoration: InputDecoration(
          suffixIcon: (_searchTextController.text.isEmpty
              ? const Icon(Icons.search)
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    clearSearch(provider);
                    FocusManager.instance.primaryFocus?.unfocus();
                  })),
          contentPadding: const EdgeInsets.only(left: 10, top: 10)),
      onChanged: (value) => onSearch(value, provider),
      onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
    );
  }

  Future clearSearch(NotesProvider provider) async {
    final loadedNotes = await HomePageRepository.loadNotes();
    provider.init(loadedNotes);
    setState(() => _searchTextController.text = '');
  }

  Future onSearch(String value, NotesProvider provider) async {
    {
      _searchTextController.text = value;
      if (_searchTextController.text.isEmpty) {
        clearSearch(provider);
        return;
      }

      final foundNotes = await HomePageRepository.findNotesByText(value);
      provider.init(foundNotes);
    }
  }

  void updateNoteInList(List<Note> notes, int noteId, String newText) {
    final noteIndex = notes.indexWhere((n) => n.id == noteId);
    if (noteIndex != -1) {
      notes[noteIndex].displayText = newText;
    }
  }

  GestureDetector noteRow(BuildContext context, Note n) {
    writeLine("Title ${n.title}");
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (c) => EditPage(noteId: n.id)));
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(
                  DateTime.now().isSameDate(n.date) ? 'today' : '',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  n.date.day.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                Text(
                  DateFormat('MMMM').format(n.date),
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  DateFormat('yyyy').format(n.date),
                  style: const TextStyle(fontSize: 12),
                )
              ],
            ),
            SizedBox(
              width: 250,
              child: n.title.isNullOrWhitespace()
                  ? Text(
                      _hideNoteTextSettings.value ? "" : n.displayText,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                    )
                  : Text(n.title!,
                      textScaler: const TextScaler.linear(1.2), overflow: TextOverflow.ellipsis, maxLines: 2),
            ),
          ],
        ));
  }

  FloatingActionButton addNoteButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (c) => const NewNotePage()));
      },
      child: const Icon(
        Icons.add,
        size: 40,
      ),
    );
  }
}
