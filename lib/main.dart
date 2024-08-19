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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    sqfliteFfiInit();
  }

  databaseFactory = databaseFactoryFfi;
  await Db.initialize();
  if (kDebugMode) {
    log('Db seed');
    await DebugUtil.seedDatabase();
  }

  runApp(ChangeNotifierProvider(
      create: (context) => NotesProvider(), child: const App()));
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  Widget currentPage = const HomePage();
  var currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'notel',
      darkTheme: ThemeData.dark(useMaterial3: true)
          .copyWith(scaffoldBackgroundColor: Color.fromARGB(255, 42, 42, 42)),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(body: currentPage, bottomNavigationBar: navbar()),
    );
  }

  BottomNavigationBar navbar() {
    return BottomNavigationBar(
      currentIndex: currentPageIndex,
      onTap: (value) => {
        switch (value) {
          0 => setState(() {
              currentPage = const HomePage();
              currentPageIndex = 0;
            }),
          1 => setState(() {
              currentPage = const SettingsPage();
              currentPageIndex = 1;
            }),
          _ => throw UnimplementedError(),
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings')
      ],
    );
  }
}
