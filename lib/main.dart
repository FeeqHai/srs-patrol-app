// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/widgets/main_shell.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/views/login_screen.dart';
import 'features/attendance/providers/attendance_provider.dart';
import 'features/incident/providers/incident_provider.dart';
import 'features/incident/views/incident_report_screen.dart';

void main() async {
  // Ensure engine is awake before calling native Firebase code
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Wrap the entire app in a MultiProvider so any module can access the Auth State
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => IncidentProvider()),
      ],
      child: const MyApp(),
    ),
  );
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
      // Hand routing control to the AuthGate instead of hardcoding MainShell
      home: const AuthGate(),
    );
  }
}

/// The AuthGate acts as the bouncer for your application.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder constantly listens to the Firebase Auth token on the device
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. While Firebase is checking the local cache for a token, show a loader
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. If a valid user token is found, unlock the KRT/SRS Main Dashboard
        if (snapshot.hasData) {
          return const MainShell();
        }

        // 3. If no user is found (logged out), force them to the Login Screen
        return const LoginScreen();
      },
    );
  }
}