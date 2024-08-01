import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:notel/main.dart';
import 'db.dart';
import 'edit_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // used to save loaded notes. might be bad for memory if no pagination on scroll
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
          margin: const EdgeInsets.only(top: 35),
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
      // TODO we want a X for clearing input?
      // mb search is a popup buttton and then we just have a back button to hide search?
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

  // TODO rätt väg är state ´manager, with shared list of Notes. When creating a note we just push the created note. so that when searching or scrolling we maintain our position? idk have to rethink the search logic
  // alternativet är ju någon form av pagination när vi har en mer scrollable lazy loaded list idk får se
  // kan man ba ersätta den som ändrats eller är de fel? kanske så är enklast shared provider of notes kan temp skita i pagination o sånt. får kolla chat gpt etc../se hur ska göra, kanske att edit skickar tillbaks noten och så kan vi i home ba edita?

  void updateNoteInList(List<Note> notes, int noteId, String newText) {
    final noteIndex = notes.indexWhere((n) => n.id == noteId);
    if (noteIndex != -1) {
      notes[noteIndex].text = newText;
    }
  }

  void handleEditPageResult(EditPageResult result) {
    switch (result.operation) {
      case EditPageOperation.remove:
        setState(() {
          notes.removeWhere((n) => n.id == result.noteId);
          allNotes.removeWhere((n) => n.id == result.noteId);
        });
        break;
      case EditPageOperation.update:
        HomePageRepository.loadNote(result.noteId).then((updatedNote) {
          setState(() {
            updateNoteInList(notes, result.noteId, updatedNote.text);
            updateNoteInList(allNotes, result.noteId, updatedNote.text);
          });
        });
        break;
      case EditPageOperation.add:
        HomePageRepository.loadNote(result.noteId).then((updatedNote) {
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
        break;
      default:
    }
  }

  GestureDetector noteRow(BuildContext context, Note n) {
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () async {
          final result = await Navigator.push(context,
              MaterialPageRoute(builder: (c) => EditPage(noteId: n.id)));

          handleEditPageResult(result);
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
                // consider using a divider to display year like subtrack. less clutter for current year?
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
        final result = await Navigator.push(
            context, MaterialPageRoute(builder: (c) => const EditPage()));
        handleEditPageResult(result);
      },
      child: const Icon(
        Icons.add,
        size: 40,
      ),
    );
  }
}

extension DateTimeExtensions on DateTime {
  bool isSameDate(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}

extension StringExtensions on String {
  bool isEmptyOrWhitespace() => trim().isEmpty;
}

class HomePageRepository {
  static Future<Iterable<Note>> loadNotes() async {
    // todo should select 36 chars from every insert not just first insert
    final rows = await Db.instance.rawQuery(r'''SELECT
        id,
        substr((CASE WHEN LENGTH(text) > 0 THEN json_extract(text, '$[0].insert') ELSE '' END), 0, 36) text,
        date
        FROM NOTE
        ORDER BY date DESC
        ''');

    return rows.map(Note.fromMap);
  }

  static Future<Note> loadNote(int noteId) async {
    final rows = await Db.instance.rawQuery(r'''SELECT
        id,
        substr((CASE WHEN LENGTH(text) > 0 THEN json_extract(text, '$[0].insert') ELSE '' END), 0, 36) text,
        date
        FROM NOTE
        WHERE id = ?
        ''', [noteId]);

    return rows.map(Note.fromMap).first;
  }

  static Future<Iterable<int>> findNoteIdsByText(text) async {
    {
      final rows = await Db.instance.rawQuery(r'''SELECT Note.id
FROM Note,
     json_each(Note.text) AS json_data
WHERE json_extract(json_data.value, '$.insert') LIKE ?
ORDER BY Note.date DESC
        ''', ['%$text%']);
      return rows.map((row) => int.parse(row['id'].toString()));
    }
  }
}
