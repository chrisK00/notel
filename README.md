## Up for grabs 🔥
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
- Dispose DB connection if required on app exit
https://stackoverflow.com/questions/60184497/how-to-execute-code-before-app-exit-flutter
- build and deploy app
https://www.youtube.com/watch?v=ZnufaryH43s
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

## Guides
- flutter quill https://github.com/singerdmx/flutter-quill/blob/master/doc/code_introduction.md
- sqflite https://docs.flutter.dev/cookbook/persistence/sqlite
- sqflite https://medium.com/@dpatel312002/guide-for-sqflite-in-flutter-59e429db1088
- sqflite https://blog.stackademic.com/efficient-sqlite-database-operations-in-flutter-using-sqflite-643034389a4c
- Notes app https://www.youtube.com/watch?v=yW9jtWGHmuE&list=PLzzt2WMkurR2kE9TPm4BwW5XrvdavgZiV&index=12

## Getting Started
//the application state is not lost during the reload. To reset the state, use hot restart instead.

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


