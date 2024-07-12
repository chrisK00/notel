import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import 'db.dart';
import 'edit_page.dart';

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

class App extends StatelessWidget {
  const App({super.key});

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
      home: HomePage(),
    );
  }
}

// is this really stateless? will this reload when user presses back after creating Note
class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // TODO this will only contain a few lines of the actual note text, would be good to mb have some pagination on scroll aswell.
  final notes = <Note>[];

  // TODO add orderby date
  Future<void> loadNotes(Database db) async {
    // TODO: hack
    if (notes.isNotEmpty) {
      return;
    }
    log('loading notes');
    final rows =
        await db.rawQuery("select id,substr(text, 0, 36) text, date from Note");
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
    Db.open().then(loadNotes);

    return Scaffold(
        body: Container(
          margin: const EdgeInsets.only(top: 40),
          child: Column(
              children: notes
                  .map((n) => GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        // osäker på om det är korrekt att använda navigator
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (c) => EditPage(noteId: n.id)));
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text(
                              DateFormat('d MMMM yyyy').format(n.date),
                            ),
                            SizedBox(
                              width: 200,
                              child: Text(
                                n.text,
                              ),
                            ),
                          ],
                        ),
                      )))
                  .toList()),
        ),
        bottomNavigationBar: Container(
          margin: const EdgeInsets.only(right: 10, bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (c) => const EditPage())),
                child: const Icon(
                  Icons.add,
                  size: 40,
                ),
              ),
            ],
          ),
        ));
  }
}
