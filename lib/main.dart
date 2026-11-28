import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:notel/utils/db_seed.dart';
import 'package:provider/provider.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'infrastructure/db.dart';
import 'infrastructure/note.dart';
import 'note_page/edit_page.dart';
import 'home_page/home_page.dart';
import 'activity_log/activity_calendar_page.dart';
import 'notes_provider.dart';
import 'settings_page/settings_page.dart';
import 'infrastructure/settings_repository.dart';

import 'home_page/category_drawer.dart';

/// Global key so DB errors can show snackbars without needing a BuildContext.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final navigatorKey = GlobalKey<NavigatorState>();

class AppErrors {
  static void showError(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => scaffoldMessengerKey.currentState?.hideCurrentSnackBar(),
        ),
      ),
    );
  }
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Platform.isWindows) {
      sqfliteFfiInit();
    }

// TODO fÃ¶rsiktig pÃ¥ att kÃ¶ra detta pÃ¥ existerande machine, kan ta bort DBn!! borde dÃ¶pa om appen if in debug
    databaseFactory = databaseFactoryFfi;
    await Db.initialize(useDebugDatabase: kDebugMode);

// TODO comment if running this locally
    if (kDebugMode) {
      log('Db seed');
      await DebugUtil.seedDatabase();
    }

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      log(
        'Flutter error',
        error: details.exception,
        stackTrace: details.stack,
        name: 'notel.flutter',
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      log(
        'Uncaught platform error',
        error: error,
        stackTrace: stack,
        name: 'notel.platform',
      );
      return true;
    };

    runApp(ChangeNotifierProvider(create: (context) => NotesProvider(), child: const App()));
  }, (error, stack) {
    log(
      'Uncaught zone error',
      error: error,
      stackTrace: stack,
      name: 'notel.zone',
    );
  });
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Widget currentPage = const HomePage();
  var currentPageIndex = 0;
  AppTheme _appTheme = AppTheme.dark;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onDetach: () async {
        await Db.instance.close();
      },
    );
    _loadAppTheme();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreActiveNote();
    });
  }

  Future<void> _restoreActiveNote() async {
    try {
      final repo = SettingsRepository(Db.instance);
      final restoreSetting = await repo.getOrNull(
        BoolSettings.restoreActiveNoteKey,
        BoolSettings.fromMap,
      );
      if (restoreSetting != null && !restoreSetting.value) return;

      final activeNoteSetting = await repo.getOrNull(
        StringSettings.activeNoteIdKey,
        StringSettings.fromMap,
      );
      final noteIdStr = activeNoteSetting?.value;
      if (noteIdStr == null || noteIdStr.isEmpty) return;
      final noteId = int.tryParse(noteIdStr);
      if (noteId == null || noteId <= 0) return;

      final rows = await Db.instance.query(
        'Note',
        where: 'id = ?',
        whereArgs: [noteId],
      );
      if (rows.isEmpty || !mounted) return;

      final note = Note.fromMap(rows.first);
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => EditPage(noteId: note.id, initialNote: note),
        ),
      );
    } catch (_) {}
  }

  Future<void> _loadAppTheme() async {
    final setting = await SettingsRepository(Db.instance).getOrNull(
      StringSettings.themeModeKey,
      StringSettings.fromMap,
    );
    if (!mounted) return;
    setState(() {
      _appTheme = AppTheme.fromString(setting?.value);
      if (currentPageIndex == 3) {
        currentPage = SettingsPage(
          appTheme: _appTheme,
          onAppThemeChanged: _setAppTheme,
        );
      }
    });
  }

  Future<void> _setAppTheme(AppTheme theme) async {
    setState(() {
      _appTheme = theme;
      if (currentPageIndex == 3) {
        currentPage = SettingsPage(
          appTheme: theme,
          onAppThemeChanged: _setAppTheme,
        );
      }
    });
    await SettingsRepository(Db.instance).insertOrUpdate(
      StringSettings.themeModeKey,
      () => StringSettings(StringSettings.themeModeKey, theme.name).toMap(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final darkTheme = ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color.fromARGB(255, 40, 40, 40),
    );
    final blackTheme = ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      cardColor: const Color.fromARGB(255, 18, 18, 18),
      cardTheme: const CardThemeData(
        color: Color.fromARGB(255, 20, 20, 20),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color.fromARGB(255, 22, 22, 22),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color.fromARGB(255, 16, 16, 16),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
        surface: const Color.fromARGB(255, 20, 20, 20),
      ),
    );
    final lightTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'notel',
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      darkTheme: _appTheme == AppTheme.black ? blackTheme : darkTheme,
      theme: lightTheme,
      themeMode: _appTheme == AppTheme.light ? ThemeMode.light : ThemeMode.dark,
      home: Scaffold(
        key: _scaffoldKey,
        drawer: const CategoryDrawer(),
        body: currentPage,
        bottomNavigationBar: navbar(),
      ),
    );
  }

  BottomNavigationBar navbar() {
    return BottomNavigationBar(
      currentIndex: currentPageIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (value) {
        switch (value) {
          case 0:
            // UniqueKey forces a new HomePage State so search clears, list
            // reloads, and scroll resets (same-type swap would reuse State).
            setState(() {
              Provider.of<NotesProvider>(context, listen: false).clearSelectedCategory();
              currentPage = HomePage(key: UniqueKey());
              currentPageIndex = 0;
            });
            break;
          case 1:
            if (currentPageIndex != 0) {
              setState(() {
                currentPage = const HomePage();
                currentPageIndex = 0;
              });
            }
            _scaffoldKey.currentState?.openDrawer();
            break;
          case 2:
            setState(() {
              currentPage = const ActivityCalendarPage();
              currentPageIndex = 2;
            });
            break;
          case 3:
            setState(() {
              currentPage = SettingsPage(
                appTheme: _appTheme,
                onAppThemeChanged: _setAppTheme,
              );
              currentPageIndex = 3;
            });
            break;
          default:
            throw UnimplementedError();
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.folder_outlined), label: 'Categories'),
        BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined), label: 'Kalender'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }
}
