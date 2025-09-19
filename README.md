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