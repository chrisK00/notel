### Testing & CI
- **Run all Flutter tests:**
  ```bash
  flutter test
  ```
- **Run CLI unit tests (Playground):**
  ```bash
  dart test
  # Or inside notel_playground_cli
  cd notel_playground_cli && dart test
  ```
- **Continuous Integration:**
  - Automated tests run on every push and pull request via [`.github/workflows/test.yml`](.github/workflows/test.yml).

### Releasing & APK Builds
- **Automated GitHub Releases:**
  - Pushing a tag matching `v*` (e.g. `git tag v1.1.0 && git push origin v1.1.0`) triggers [`.github/workflows/release.yml`](.github/workflows/release.yml).
  - GitHub Actions runs `flutter build apk --split-per-abi` and publishes the ABI-specific APKs directly to GitHub Release assets.

### How to deploy manually
- Run
```bash
flutter build apk --split-per-abi
```
- Connect Android device to PC
- Modify the device id and run
 ```bash
 flutter install --device-id 2107113SG --use-application-binary=build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
 ```
 ```bash
 flutter install --device-id SM S926B --use-application-binary=build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
 ```
 samsung device id: SM S926B
 elma device id: 2107113SG
### Notes
- Log output filter: `!D/`, `!I/`, `!E/`, `!W/`

## Updating Gradle
First update `com.android.application` in `settings.gradle` file id `"com.android.application"` version `"8.3.2"` apply false.

After that, inside `gradle/wrapper/gradle-wrapper.properties` set:
```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.4-all.zip
```
Then restart the IDE.

## Guides
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [Online documentation](https://docs.flutter.dev/)
- [Flutter Quill Docs](https://github.com/singerdmx/flutter-quill/blob/master/doc/code_introduction.md)
- [Sqflite Persistence Guide](https://docs.flutter.dev/cookbook/persistence/sqlite)
- [Provider State Management](https://docs.flutter.dev/data-and-backend/state-mgmt/simple)

## Icons
- [Material Icons Reference](https://api.flutter.dev/flutter/material/Icons-class.html)

📌 Links & References
* Scaler Flutter Pagination: https://www.scaler.com/topics/pagination-in-flutter/
* Medium Package-less Pagination: https://medium.com/@m1nori/flutter-pagination-without-any-packages-8c24095555b3
* Infinite Scroll Package: https://pub.dev/packages/infinite_scroll_pagination
* Flutter App Exit Lifecycle: https://stackoverflow.com/questions/60184497
* Android Deployment Docs: https://docs.flutter.dev/deployment/android
* YouTube Tutorial Playlist: https://m.youtube.com/playlist?list=PLbhaS_83B97vONkOAWGJrSXWX58et9zZ2
* Flutter Quill Toolbar Ref: https://www.youtube.com/watch?v=L2qG-qlhx-s&list=PLzzt2WMkurR2kE9TPm4BwW5XrvdavgZiV&index=3
*
