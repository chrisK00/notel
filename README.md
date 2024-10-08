## Up for grabs 🔥
- display day of week 
- tags/keywords e.g sök efter start auto complete eller ha tagg på note. $dia. man lan skapa egna såna text shortcuts? fan vad nice
- option to hide note text on home page?
- date filter
- On search show keywords what searched for in description take that part that was searched fir e.g blodtryck search ser alla värden
Enklast är nog bara att man highlightar alla occurrences och kanske visar i UI någon siffra på antal hittade matchningar. sen får man se till att onsave inte tar med de deltas som skapas
- elm tycker title smart ide
- ta ner lite UI är för långt upp
<!-- - fix bugg when saving note and not using arrow to go back but using the android buttons the event is not called. gesturedetector or smtn. alternativt bara alltid ladda in notes lmao. avvakta med search/ use search tab --> Just nu går ej visa dialog on changes not saved
- // TODO kan vi fixa padding TOP?/ Transform för att flytta upp Column. för date rows
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
- felhantering?
- Encrypt exported notes
- Export/Import maybe add store in gdrive support if safe without backend? import notes dialog Are you sure you would like to import x amount of notes
- smileys för o spåra vilka dagar e mest skit o hur ofta/vad gör de skit. insights page
- export reminder
- log note reminder notification
- how to access sqlite database in emulator
- Proper deploy https://docs.flutter.dev/deployment/android
- rebase git history o gör public
- dela notes på något snyggt sätt, en till vy but readonly?

## Guides
- flutter quill https://github.com/singerdmx/flutter-quill/blob/master/doc/code_introduction.md
- sqflite https://docs.flutter.dev/cookbook/persistence/sqlite
- sqflite https://medium.com/@dpatel312002/guide-for-sqflite-in-flutter-59e429db1088
- sqflite https://blog.stackademic.com/efficient-sqlite-database-operations-in-flutter-using-sqflite-643034389a4c
- Notes app https://www.youtube.com/watch?v=yW9jtWGHmuE&list=PLzzt2WMkurR2kE9TPm4BwW5XrvdavgZiV&index=12
- Provider state https://docs.flutter.dev/data-and-backend/state-mgmt/simple
- callbacks https://www.digitalocean.com/community/tutorials/flutter-widget-communication
- tips and tricks https://github.com/vandadnp/flutter-tips-and-tricks?tab=readme-ov-file

### How to run
- Run `flutter run`. After making changes click on terminal tab and press R to hot reload. Alternatively just run the app using `F5`

### How to deploy
- Run
```csharp
flutter build apk --split-per-abi
```
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
- Log output
Filter !D/, !I/, !E/, !W/

## Getting Started
//the application state is not lost during the reload. To reset the state, use hot restart instead.

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


