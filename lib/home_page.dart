import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  final _textController = TextEditingController();

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

// TODO går just nu inte att scrolla listan, blir overflow
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
          margin: const EdgeInsets.only(top: 40),
          child: Column(children: [
            searchBar(),
            ...notes.map((n) => Column(
                  children: [
                    noteRow(context, n),
                    const Divider(
                      height: 15,
                      thickness: 1,
                    )
                  ],
                ))
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

  TextField searchBar() {
    return TextField(
      controller: _textController,
      decoration: const InputDecoration(
          suffixIcon: Icon(Icons.search),
          contentPadding: EdgeInsets.only(left: 10, top: 10)),
      onChanged: onSearch,
      onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
    );
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
        setState(() {
          notes.clear();
          notes.addAll(allNotes);
        });
        return;
      }

      final ids = await HomePageRepository.findNoteIdsByText(value);

      setState(() {
        notes.clear();
        notes.addAll(allNotes.where((note) => ids.contains(note.id)).toList());
      });
    }
  }

  // TODO rätt väg är Provider, with shared list of Notes. When creating a note we just push the created note. so that when searching or scrolling we maintain our position? idk have to rethink the search logic
  // alternativet är ju någon form av pagination när vi har en mer scrollable lazy loaded list idk får se
  void reloadPageData() {
    loadNotes();
    setState(() => _textController.text = '');
  }

  GestureDetector noteRow(BuildContext context, Note n) {
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (c) => EditPage(noteId: n.id)));
          reloadPageData();
        },
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
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
                width: 200,
                child: Text(
                  n.text,
                ),
              ),
            ],
          ),
        ));
  }

  FloatingActionButton addNoteButton(BuildContext context) {
    return FloatingActionButton(
      // TODO same as on click edit note
      onPressed: () async {
        await Navigator.push(
            context, MaterialPageRoute(builder: (c) => const EditPage()));
        reloadPageData();
      },
      child: const Icon(
        Icons.add,
        size: 40,
      ),
    );
  }
}

class HomePageRepository {
  static Future<Iterable<Note>> loadNotes() async {
    final rows = await Db.instance.rawQuery(r'''SELECT
        id,
        substr((CASE WHEN LENGTH(text) > 0 THEN json_extract(text, '$[0].insert') ELSE '' END), 0, 36) text,
        date
        FROM NOTE
        ORDER BY date DESC
        ''');
    final mappedRows = rows.map((n) {
      final note = Note.fromMap(n);
      log('length ${note.text.length}');
      if (note.text.length == 35) {
        // todo this wont account for the case where the full note is actually 35 chars
        note.text = "${note.text.substring(0, note.text.length - 3)}...";
      }
      return note;
    });

    return mappedRows;
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
