import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:notel/utils/db_seed.dart';
import 'package:provider/provider.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'infrastructure/db.dart';
import 'home_page/home_page.dart';
import 'notes_provider.dart';
import 'settings_page/settings_page.dart';

import 'home_page/category_drawer.dart';

/// Global key so DB errors can show snackbars without needing a BuildContext.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onDetach: () async {
        await Db.instance.close();
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'notel',
      scaffoldMessengerKey: scaffoldMessengerKey,
      darkTheme:
          ThemeData.dark(useMaterial3: true).copyWith(scaffoldBackgroundColor: const Color.fromARGB(255, 40, 40, 40)),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
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
            setState(() {
              Provider.of<NotesProvider>(context, listen: false).clearSelectedCategory();
              currentPage = const HomePage();
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
              currentPage = const SettingsPage();
              currentPageIndex = 2;
            });
            break;
          default:
            throw UnimplementedError();
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.folder_outlined), label: 'Categories'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }
}
