## Up for grabs 🔥
- Fixa search så egen tab/page fast ska ej märkas av användare ksk?? idk hur annars lösa att home page ska alltid laddas om utan o ha en massa hack... vill helst slippa onupdate o sånt, alternativet är state management.
- Refaktorera db kod till repo
- ta ner lite UI är för långt upp
<!-- - fix bugg when saving note and not using arrow to go back but using the android buttons the event is not called. gesturedetector or smtn. alternativt bara alltid ladda in notes lmao. avvakta med search/ use search tab --> Just nu går ej visa dialog on changes not saved
<!-- - Hitta ny DB -->
- fixa note.id så ej nullable...
- At top of screen where the back < button and save button are ADD inbetween  editable note date
https://www.youtube.com/watch?v=yW9jtWGHmuE&list=PLzzt2WMkurR2kE9TPm4BwW5XrvdavgZiV&index=12
- Förbättra navigatetopreviouspage i Edit page
// bättre hantera onSave so dont create new note on load?
// borde ta bort om tom, why save above etc.. better handling = slipper reload i home page etc...
- för insert current time kan ha en custom knapp i edit quill toolbar som simply trycker in texten/delta i documentet. kanske man vill ha det i bold style. den kanske ska runda till xx:x0 istället för exakt exakt? skit i det temporärt lol övertänker
- Stats page alternatively stats button when searching for a word. E.g headache shows how many notes it was in for the last month/week
// tags would be nice, e.g huvudvärk, or maybe just implement a good search feature that counts results words (if duplicated word in a day only take 1)
- Add automated tests
- Infinite scroll home page (lazy load)?
https://www.scaler.com/topics/pagination-in-flutter/
https://medium.com/@m1nori/flutter-pagination-without-any-packages-8c24095555b3
https://pub.dev/packages/infinite_scroll_pagination/example
- investigate DateOnly om man vill använda den istället / om det finns något alternativ. om man då inte vill veta tidpunkt note skapades
  DateOnly getDateOnly() => DateOnly(year, month, day);
class DateOnly
  int year; int month; int day;
  DateOnly(this.year, this.month, this.day);
  @override  String toString() => '$year-$month-$day';
- Dispose DB connection if required on app exit
https://stackoverflow.com/questions/60184497/how-to-execute-code-before-app-exit-flutter
- Split editpage into create and edit page
- Consider using another package than sqflite for DB
- prestandamätningar?
- tänk om kring cachad allnotes och notes. kanske istället använd riktig cache lol/state. alternativet är ju implement database searching etc.. de kanske efter bytt DB till bättre prestanda
- consider using a divider to display year like subtrack. less clutter for current year? mb only show year for previous year widgets?
- Encrypt exported notes
- Export/Import maybe add store in gdrive support if safe without backend?
- smileys för o spåra vilka dagar e mest skit o hur ofta/vad gör de skit. insights page
- export reminder
- log note reminder notification 
- dark+light theme
- how to access sqlite database in emulator
- Proper deploy https://docs.flutter.dev/deployment/android

## Guides
- flutter quill https://github.com/singerdmx/flutter-quill/blob/master/doc/code_introduction.md
- sqflite https://docs.flutter.dev/cookbook/persistence/sqlite
- sqflite https://medium.com/@dpatel312002/guide-for-sqflite-in-flutter-59e429db1088
- sqflite https://blog.stackademic.com/efficient-sqlite-database-operations-in-flutter-using-sqflite-643034389a4c
- Notes app https://www.youtube.com/watch?v=yW9jtWGHmuE&list=PLzzt2WMkurR2kE9TPm4BwW5XrvdavgZiV&index=12

### How to run
- Run `flutter run`. After making changes click on terminal tab and press R to hot reload. Alternatively just run the app using `F5`

### How to deploy
- Run `flutter build apk --split-per-abi`
- Connect Android device to pc
- Modify the device id and run
 ```csharp
 flutter install --device-id 2107113SG --use-application-binary=build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
 ```
 ```csharp
 flutter install --device-id  SM S926B --use-application-binary=build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
 ```
 samsung device id: SM S926B
 elma device id: 2107113SG
### notes
  // static Future<Note?> getNoteByDate(DateTime date) async {
  //   final getNoteResult = await Db.instance.query(Db.noteTable,
  //       where: "date(date)= date(?)", whereArgs: [date.toString()], limit: 1);

  //   return getNoteResult.isEmpty ? null : Note.fromMap(getNoteResult.first);
  // }

## Getting Started
//the application state is not lost during the reload. To reset the state, use hot restart instead.

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


