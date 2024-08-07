import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:notel/utils/extensions.dart';
import '../edit_page/edit_page.dart';
import '../infrastructure/note.dart';
import 'home_page_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String searchText = '';
  final _searchTextController = TextEditingController();

  final allNotes = <Note>[];
  final notes = <Note>[];

  Future loadNotes() async {
    notes.clear();
    final loadedNotes = await HomePageRepository.loadNotes();
    setState(() {
      notes.addAll(loadedNotes);
    });
  }

  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
          margin: const EdgeInsets.only(top: 60),
          child: Column(children: [
            Container(child: searchBar()),
            Expanded(
              child: ListView.separated(
                  key: const PageStorageKey('notesListKey'),
                  itemBuilder: (context, index) =>
                      noteRow(context, notes[index]),
                  separatorBuilder: (_, __) => const Divider(),
                  itemCount: notes.length),
            )
          ]),
        ),
        bottomNavigationBar: Container(
          margin: const EdgeInsets.only(right: 10, bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              addNoteButton(context),
            ],
          ),
        ));
  }

  Widget searchBar() {
    return TextField(
      controller: _searchTextController,
      decoration: InputDecoration(
          suffixIcon: (_searchTextController.text.isEmptyOrWhitespace()
              ? const Icon(Icons.search)
              : IconButton(
                  icon: const Icon(Icons.clear), onPressed: clearSearch)),
          contentPadding: const EdgeInsets.only(left: 10, top: 10)),
      onChanged: onSearch,
      onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
    );
  }

  void clearSearch() {
    setState(() {
      searchText = '';
      _searchTextController.text = '';
      notes.clear();
      notes.addAll(allNotes);
      allNotes.clear();
    });
  }

  Future onSearch(value) async {
    {
      if (allNotes.isEmpty) {
        allNotes.addAll(notes);
      }

      searchText = value.trim() ?? '';
      if (value.trim().isEmpty) {
        clearSearch();
        return;
      }

      final ids = await HomePageRepository.findNoteIdsByText(value);

      setState(() {
        notes.clear();
        notes.addAll(allNotes.where((note) => ids.contains(note.id)).toList());
      });
    }
  }

  void updateNoteInList(List<Note> notes, int noteId, String newText) {
    final noteIndex = notes.indexWhere((n) => n.id == noteId);
    if (noteIndex != -1) {
      notes[noteIndex].text = newText;
    }
  }

  EditPage createEditNotePage(int noteId) => EditPage(
        noteId: noteId,
        onUpdate: () {
          HomePageRepository.loadNote(noteId).then((updatedNote) {
            setState(() {
              updateNoteInList(notes, noteId, updatedNote.text);
              updateNoteInList(allNotes, noteId, updatedNote.text);
            });
          });
        },
        onRemove: () {
          setState(() {
            notes.removeWhere((n) => n.id == noteId);
            allNotes.removeWhere((n) => n.id == noteId);
          });
        },
      );

  EditPage createNewNotePage() => EditPage(
        onCreate: (noteId) {
          HomePageRepository.loadNote(noteId).then((updatedNote) {
            setState(() {
              // hack
              if (allNotes.length < notes.length) {
                allNotes.addAll(notes);
              }

              clearSearch();
              notes.add(updatedNote);
              notes.sort((a, b) => b.date.compareTo(a.date));
            });
          });
        },
      );

  GestureDetector noteRow(BuildContext context, Note n) {
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (c) => createEditNotePage(n.id!)));
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // TODO kan vi fixa padding TOP?/ Transform för att flytta upp Column
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
                n.text,
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
            context, MaterialPageRoute(builder: (c) => createNewNotePage()));
      },
      child: const Icon(
        Icons.add,
        size: 40,
      ),
    );
  }
}
