import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/views/login_screen.dart';
import 'features/auth/views/register_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/incident/providers/incident_provider.dart';
import 'core/widgets/main_shell.dart';
import 'features/attendance/providers/attendance_provider.dart';
import 'features/tracking/providers/tracking_provider.dart';
import 'features/post/views/admin_mobile_layout.dart';
import 'features/post/views/ketua_mobile_layout.dart';
import 'features/post/views/web_dashboard_layout.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);
  
  runApp(const SRSPatrolApp());
}

class SRSPatrolApp extends StatelessWidget {
  const SRSPatrolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => IncidentProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()), // INJECTED: The missing dependency
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
      ],
      child: MaterialApp(
        title: 'SRS Patrol System',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system, // Listens to device OS setting

        // --- DYNAMIC ROUTING ---
        home: const RootRouter(),

        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const RootRouter(), // Fixed: Maps to dynamic router instead of hardcoded MainShell
        },

        // --- LIGHT THEME ---
        theme: ThemeData(
          brightness: Brightness.light,
          primaryColor: Colors.indigo,
          scaffoldBackgroundColor: const Color(0xFFF8F9FA),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigo, width: 2)),
            labelStyle: TextStyle(color: Colors.grey.shade600),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 3,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          ),
        ),

        // --- DARK THEME ---
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.indigoAccent,
          scaffoldBackgroundColor: const Color(0xFF121212),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E1E1E),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF2C2C2C),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade700, width: 1)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent, width: 2)),
            labelStyle: TextStyle(color: Colors.grey.shade400),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF1E1E1E),
            elevation: 3,
            shadowColor: Colors.black54,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          ),
        ),

      ),
    );
  }
}

class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isAuthenticated) {
          if (authProvider.role == 'ketua_krt' || authProvider.role == 'ketua') {
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return const WebDashboardLayout(); // Web
                }
                return const AdminMobileLayout(); // Mobile
              },
            );
          } else if (authProvider.role == 'ketua_peronda') {
            return const KetuaMobileLayout(); // Custom Mobile for Squad Leader
          } else {
            return const MainShell(); // Normal Mobile for Patroller
          }
        }
        return const LoginScreen();
      },
    );
  }
}