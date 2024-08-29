import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  Future loadNotes() async {
    final loadedNotes = await HomePageRepository.loadNotes();
    final provider = Provider.of<NotesProvider>(context, listen: false);
    provider.init(loadedNotes);
  }

  @override
  void initState() {
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
                  itemBuilder: (context, index) =>
                      noteRow(context, provider.notes[index]),
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
                  onPressed: () => clearSearch(provider))),
          contentPadding: const EdgeInsets.only(left: 10, top: 10)),
      onChanged: (value) => onSearch(value, provider),
      onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
    );
  }

  Future clearSearch(NotesProvider provider) async {
    final loadedNotes = await HomePageRepository.loadNotes();
    provider.init(loadedNotes);
    FocusManager.instance.primaryFocus?.unfocus();
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
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (c) => EditPage(noteId: n.id)));
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(
                  DateTime.now().isSameDate(n.date) ? 'today' : '',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  n.date.day.toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20),
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
              child: Text(
                n.displayText,
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
            ),
          ],
        ));
  }

  FloatingActionButton addNoteButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () async {
        await Navigator.push(
            context, MaterialPageRoute(builder: (c) => const NewNotePage()));
      },
      child: const Icon(
        Icons.add,
        size: 40,
      ),
    );
  }
}
