import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: HomePage(),
    );
  }
}

class Note {
  String text = "";
  DateTime date = DateTime.now();
  Note({this.text = "", DateTime? date}) : date = date ?? DateTime.now();
}

class HomePage extends StatelessWidget {
  // TODO this will only contain a few lines of the actual note text, would be good to have some pagination on scroll aswell
  final notes = <Note>[];

  @override
  Widget build(BuildContext context) {
    notes.addAll([
      Note(text: "hi", date: DateTime.now()),
      Note(text: "sup"),
      Note(text: "beep")
    ]);

    return Column(
        children: notes
            .map((n) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      DateFormat('d MMMM yyyy').format(n.date),
                      textScaler: const TextScaler.linear(0.5),
                    ),
                    Text(
                      n.text,
                      textScaler: const TextScaler.linear(0.5),
                    )
                  ],
                ))
            .toList());
  }
}

class EditPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  final _controller = QuillController.basic();

  @override
  void initState() {
    super.initState();
    _controller.document.changes.listen(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(event) {
    print('$event');
    final text = _controller.document.toPlainText();
    print('Text changed: $text');
    // https://stackoverflow.com/questions/71815023/dart-how-to-listen-for-text-change-in-quill-text-editor-flutter
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color.fromARGB(255, 224, 234, 238),
        body: Container(
            margin: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        onPressed: () => {},
                        icon:
                            const Icon(Icons // todo popup if changes were made
                                .arrow_back)),
                    IconButton(
                        onPressed: () => {}, icon: const Icon(Icons.save))
                  ],
                ),
                // https://www.youtube.com/watch?v=L2qG-qlhx-s&list=PLzzt2WMkurR2kE9TPm4BwW5XrvdavgZiV&index=3
                // TODO at top of screen back < button and save button and inbetween add also note date
                // TODO tags would be nice, e.g huvudvärk, or maybe just implement a good search feature that counts results words (if duplicated word in a day only take 1)
                // TODO: move toolbar to bottom of screen

                Expanded(
                    child: QuillEditor.basic(
                        configurations: QuillEditorConfigurations(
                            controller: _controller, expands: true))),
                QuillToolbar.simple(
                  configurations: QuillSimpleToolbarConfigurations(
                    showFontFamily: false,
                    showCodeBlock: false,
                    showUnderLineButton: false,
                    showSubscript: false,
                    showSuperscript: false,
                    showClearFormat: false,
                    showIndent: false,
                    showLink: false,
                    showClipboardCopy: false,
                    showClipboardCut: false,
                    showInlineCode: false,
                    multiRowsDisplay: false,
                    controller: _controller,
                    // buttonOptions: QuillSimpleToolbarButtonOptions(
                    //     fontSize:
                    //         QuillToolbarFontSizeButtonOptions(itemHeight: 0))
                    // customButtons: [ // instead just have a custom button somewhere popup save sticky that doesnt disappear or whatever
                    //   QuillToolbarCustomButtonOptions(
                    //     icon: Icon(Icons.save),
                    //     onPressed: () => {},
                    //   ),
                    // ]
                  ),
                ),
              ],
            )));
  }
}
