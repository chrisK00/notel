import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:notel/db_seed.dart';
import 'db.dart';
import 'home_page.dart';
import 'settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Db.initialize();
  if (kDebugMode) {
    log('Db seed');
    await DebugUtil.seedDatabase();
  }
  runApp(const App());
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
      title: 'Flutter Demo',
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
              currentPage = SettingsPage();
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

// todo om user backar med deras back button vad blir resultatet?null?
class EditPageResult {
  final EditPageOperation operation;
  final int noteId;
  EditPageResult(this.operation, this.noteId);
}

enum EditPageOperation { remove, update, add }
