// File: lib/main.dart
import 'package:flutter/material.dart';
import 'core/widgets/main_shell.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SRS App',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueGrey,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      // Launching the shell we created in Step 1
      home: const MainShell(),
    );
  }
}