// ==========================================
// File: lib/main.dart
// ==========================================

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// --- 1. Auth Module Imports ---
import 'features/auth/providers/auth_provider.dart';
// Note: You probably have an AuthGate or LoginScreen import here normally,
// but we are bypassing it right now to test the camera.

// --- 2. Attendance/Shift Module Imports ---
import 'features/attendance/providers/attendance_provider.dart';

// --- 3. Incident Module Imports ---
import 'features/incident/providers/incident_provider.dart';
import 'features/incident/views/incident_report_screen.dart'; // The screen we are testing

void main() async {
  // Ensure the Flutter engine is running before calling Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Boot up the connection to your Firebase Database & Storage
  await Firebase.initializeApp();

  runApp(
    // MultiProvider sits at the absolute top of the app,
    // wrapping everything so any screen can access these services.
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
      title: 'SRS Patrol',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
      ),
      // THE PENETRATION TEST BYPASS:
      // We are temporarily forcing the app to load the Incident UI on startup
      // instead of the Login Screen so you can immediately test the camera and upload.
      home: const IncidentReportScreen(),
    );
  }
}