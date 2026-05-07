import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // REQUIRED: Import the provider package
import 'features/auth/views/login_screen.dart';
import 'features/auth/views/register_screen.dart';
import 'features/auth/providers/auth_provider.dart'; // REQUIRED: Import your provider

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SRSPatrolApp());
}

class SRSPatrolApp extends StatelessWidget {
  const SRSPatrolApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1. Wrap the entire app in a MultiProvider
    return MultiProvider(
      providers: [
        // 2. Inject the AuthProvider into the widget tree
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // Note: When you rebuild your IncidentProvider later, you will add it here:
        // ChangeNotifierProvider(create: (_) => IncidentProvider()),
      ],
      // 3. Your MaterialApp remains exactly the same as before
      child: MaterialApp(
        title: 'SRS Patrol System',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
        },
      ),
    );
  }
}