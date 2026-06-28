import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/views/login_screen.dart';
import 'features/auth/views/register_screen.dart';
import 'features/auth/views/change_password_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/incident/providers/incident_provider.dart';
import 'core/widgets/main_shell.dart';
import 'features/tracking/providers/tracking_provider.dart';
import 'features/attendance/providers/attendance_provider.dart';
import 'features/post/views/admin_shell.dart';
import 'features/post/views/ketua_mobile_layout.dart';
import 'core/providers/settings_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/services/sos_alert_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SosAlertService().initialize();

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
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            navigatorKey: SosAlertService.navigatorKey,
            title: 'SRS Patrol System',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.light,
            locale: settings.locale,
            supportedLocales: const [Locale('ms'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // --- DYNAMIC ROUTING ---
            home: const RootRouter(),

            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/home': (context) =>
                  const RootRouter(), // Fixed: Maps to dynamic router instead of hardcoded MainShell
            },

            // --- LIGHT THEME ---
            theme: ThemeData(
              brightness: Brightness.light,
              primaryColor: const Color(0xFF0F3D87),
              scaffoldBackgroundColor: const Color(0xFFF8F9FA),
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF0F3D87),
                secondary: Color(0xFFFFD100),
                surface: Color(0xFFF8F9FA),
                onSurface: Colors.black87,
              ),
              popupMenuTheme: const PopupMenuThemeData(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
              ),
              bottomSheetTheme: const BottomSheetThemeData(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF0F3D87),
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                titleTextStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF0F3D87),
                    width: 2,
                  ),
                ),
                labelStyle: TextStyle(color: Colors.grey.shade600),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F3D87),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: const Color(0xFF0F3D87).withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              cardTheme: CardThemeData(
                color: Colors.white,
                elevation: 3,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                selectedItemColor: const Color(0xFF0F3D87),
                unselectedItemColor: Colors.grey.shade500,
                selectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
              ),
            ),

            // --- DARK THEME ---
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primaryColor: const Color(0xFF0F3D87),
              scaffoldBackgroundColor: const Color(0xFF121212),
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF0F3D87),
                secondary: Color(0xFFFFD100),
                surface: Color(0xFF121212),
                onSurface: Colors.white,
              ),
              popupMenuTheme: const PopupMenuThemeData(
                color: Color(0xFF1E1E1E),
                surfaceTintColor: Colors.transparent,
              ),
              bottomSheetTheme: const BottomSheetThemeData(
                backgroundColor: Color(0xFF1E1E1E),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: const Color(0xFF1E1E1E),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                titleTextStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
              cardTheme: CardThemeData(
                color: const Color(0xFF1E1E1E),
                elevation: 4,
                shadowColor: Colors.black45,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white12, width: 1),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade700, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF0F3D87),
                    width: 2,
                  ),
                ),
                labelStyle: TextStyle(color: Colors.grey.shade400),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F3D87),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: const Color(0xFF0F3D87).withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                selectedItemColor: const Color(0xFFFFD100),
                unselectedItemColor: Colors.grey.shade600,
                selectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
              ),
            ),
          );
        },
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
          SosAlertService().startPolling(context);
          if (authProvider.mustChangePassword) {
            return const ChangePasswordScreen();
          }
          if (authProvider.role == 'ketua_krt' ||
              authProvider.role == 'ketua' ||
              authProvider.role == 'super_admin') {
            return const AdminShell(); // Responsive Admin Shell
          } else if (authProvider.role == 'ketua_peronda') {
            return const KetuaMobileLayout(); // Responsive Squad Leader Shell
          } else {
            return const MainShell(); // Responsive Patroller Shell
          }
        } else {
          SosAlertService().stopPolling();
          return const LoginScreen();
        }
      },
    );
  }
}
