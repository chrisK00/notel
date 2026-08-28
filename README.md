### How to run
- Run `flutter run`. After making changes click on terminal tab and press R to hot reload. Alternatively just run the app using `F5`
Note that the application state is not lost during the hot reload. To reset the state, use hot restart instead.

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

## Updating Gradle
First Update com.android.application in settings.gradle file id "com.android.application" version "8.3.2" apply false

After That come in gradle folder inside wrapper folder you'll find gradle-wrapper.properties add this:

distributionUrl=https\://services.gradle.org/distributions/gradle-8.4-all.zip
Then Restart the IDE

## Guides
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [online documentation](https://docs.flutter.dev/),

- flutter quill https://github.com/singerdmx/flutter-quill/blob/master/doc/code_introduction.md
- sqflite https://docs.flutter.dev/cookbook/persistence/sqlite
- sqflite https://medium.com/@dpatel312002/guide-for-sqflite-in-flutter-59e429db1088
- sqflite https://blog.stackademic.com/efficient-sqlite-database-operations-in-flutter-using-sqflite-643034389a4c
- Notes app https://www.youtube.com/watch?v=yW9jtWGHmuE&list=PLzzt2WMkurR2kE9TPm4BwW5XrvdavgZiV&index=12
- Provider state https://docs.flutter.dev/data-and-backend/state-mgmt/simple
- callbacks https://www.digitalocean.com/community/tutorials/flutter-widget-communication
- tips and tricks https://github.com/vandadnp/flutter-tips-and-tricks?tab=readme-ov-file

## Icons
https://api.flutter.dev/flutter/material/Icons-class.html

## Deferred / Complex Backlog

Items that were intentionally skipped because they are high-effort, need external services, or require design decisions before starting.

### Categories / Tag Grouping
Group notes by frequently-occurring words or shared titles into a browsable categories view. Requires a word-frequency pass over all note deltas (scan `json_each` across all rows) and a UI to let the user ignore stop-words (e.g. "jag", "så"). Possibly store a pre-computed tag column updated on each save. High complexity, skip until core UX is stable.

### Note Templates
A set of pre-filled Quill delta templates selectable when creating a new note (e.g. medication log, daily check-in). Could be a button in the toolbar or a template picker on the new-note entry point. Needs a templates table or bundled JSON file. Medium effort.

### Text Shortcuts / Keywords
Custom shortcuts in the editor (e.g. `$dia` expands to a predefined phrase). Would extend the existing `..` time-shortcut mechanism. Needs a settings UI to manage shortcut→expansion pairs and storage in the Settings table. Medium effort.

### Advanced Search
Chrome DevTools-style query language: date range filters, `startswith:`, field-specific search (`title:`), etc. Needs a query parser on top of the existing `findNotesByText`. High effort — worth doing only after basic search UX is validated.

### Search Result Highlighting
Highlight matched query terms inside note preview cards without writing temporary deltas back to the DB. Needs a custom `TextSpan`-based renderer that wraps the preview text. Medium effort.

### Stats & Insights Page
Track word-occurrence frequency over time (e.g. "headache" count per week/month, deduped per day). Requires an aggregate query over all note text and a chart widget (`fl_chart` or similar). Medium-high effort.

### Google Drive Backup
Store the SQLite database in Google Drive's `appdata` scope (invisible to users, app-private). Requires `google_sign_in` + `googleapis` packages, OAuth consent screen setup, and a background sync strategy. High effort and needs Google Cloud project setup.

### Monthly Export Reminder
Show a notification or in-app prompt once a month reminding the user to export. Requires `flutter_local_notifications` and persistent tracking of the last export date in Settings. Low-medium effort once notifications are set up.

### Automated Tests & Public Repo
Write widget and unit tests, do a `git rebase -i` to clean history, configure GitHub Actions for Android release builds. Tracked separately from feature work.

### DateOnly Class Investigation
Consider replacing `DateTime` for note creation dates with a `DateOnly(year, month, day)` value class to make it explicit that time-of-day is irrelevant for the note date field. Low risk but touches the DB date column parsing — do in a single focused PR.

### SQLite Direct Access on Android Emulator
Use `adb shell` + `run-as com.example.notel` to pull the database file, then open it with DB Browser for SQLite. No code change needed — just a workflow note.

📌 Links & References
* Scaler Flutter Pagination: https://www.scaler.com/topics/pagination-in-flutter/
* Medium Package-less Pagination: https://medium.com/@m1nori/flutter-pagination-without-any-packages-8c24095555b3
* Infinite Scroll Package: https://pub.dev/packages/infinite_scroll_pagination
* Flutter App Exit Lifecycle: https://stackoverflow.com/questions/60184497
* Android Deployment Docs: https://docs.flutter.dev/deployment/android
* YouTube Tutorial Playlist: https://m.youtube.com/playlist?list=PLbhaS_83B97vONkOAWGJrSXWX58et9zZ2
* Flutter Quill Toolbar Ref: https://www.youtube.com/watch?v=L2qG-qlhx-s&list=PLzzt2WMkurR2kE9TPm4BwW5XrvdavgZiV&index=3
*