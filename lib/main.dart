import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'db.dart';
import 'edit_page.dart';
import 'settings_page.dart';

void main() async {
// Avoid errors caused by flutter upgrade.
  WidgetsFlutterBinding.ensureInitialized();
  final db = await Db.open();
  if (kDebugMode) {
    log('Db seed');
    await Db.seed(db);
  }
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  Widget currentPage = const HomePage();
  var currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(body: currentPage, bottomNavigationBar: navbar()),
    );
  }

  BottomNavigationBar navbar() {
    return BottomNavigationBar(
      currentIndex: currentPageIndex,
      onTap: (value) => {
        switch (value) {
          0 => setState(() {
              currentPage = const HomePage();
              currentPageIndex = 0;
            }),
          1 => setState(() {
              currentPage = SettingsPage();
              currentPageIndex = 1;
            }),
          _ => throw UnimplementedError(),
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings')
      ],
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // used to save loaded notes. might be bad for memory if no pagination on scroll
  String searchText = '';
  final allNotes = <Note>[];
  final notes = <Note>[];

  Future<void> loadNotes(Database db) async {
    // TODO: hack
    if (notes.isNotEmpty) {
      return;
    }

    final rows = await db.rawQuery(r'''SELECT
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
    }).toList();
    setState(() {
      notes.addAll(mappedRows);
    });
  }

  @override
  Widget build(BuildContext context) {
    // hack LuL
    // TODO LEARN ABOUT STATE MANAGEMENT SMH
    if (allNotes.isEmpty) {
      Db.open().then(loadNotes);
      allNotes.addAll(notes);
    } else {
      if (searchText.isNotEmpty) {
        onSearch(searchText);
      } else {
        Db.open().then(loadNotes);
      }
      // search if has searchTerm
      // load all if no searchTerm
    }

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

      searchText = value.trim() ?? '';
      if (value.trim().isEmpty) {
        setState(() {
          notes.clear();
          notes.addAll(allNotes);
        });
        return;
      }

      final db = await Db.open();
      final rows = await db.rawQuery(r'''SELECT Note.id
FROM Note,
     json_each(Note.text) AS json_data
WHERE json_extract(json_data.value, '$.insert') LIKE ?
ORDER BY Note.date DESC
        ''', ['%$value%']);
      final ids = rows.map((row) => row['id']).toList();

      setState(() {
        notes.clear();
        notes.addAll(allNotes.where((note) => ids.contains(note.id)).toList());
      });
    }
  }

  GestureDetector noteRow(BuildContext context, Note n) {
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () async {
          // osäker på om det är korrekt att använda navigator
          final reloadPage = await Navigator.push(context,
              MaterialPageRoute(builder: (c) => EditPage(noteId: n.id)));
          // TODO: rethink this process. if we are scrolling we dont want to lose scroll position/same with search
          // This seems to cause some lag
          if (reloadPage) {
            setState(() => notes.clear());
          }
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
        final reloadPage = await Navigator.push(
            context, MaterialPageRoute(builder: (c) => const EditPage()));
        if (reloadPage) {
          setState(() => notes.clear());
        }
      },
      child: const Icon(
        Icons.add,
        size: 40,
      ),
    );
  }
}
