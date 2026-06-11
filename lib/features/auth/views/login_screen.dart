// File: lib/features/auth/views/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access the provider state
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/icon.png', height: 100),
              const SizedBox(height: 20),
              const Text(
                'SRS Patrol Portal',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              // Email Field
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              // Password Field
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 30),

              // Error Message Display
              if (authProvider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    authProvider.errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Login Button or Loading Spinner
              SizedBox(
                width: double.infinity,
                height: 50,
                child: authProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  // 1. Mark the callback as asynchronous
                  onPressed: () async {
                    if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {

                      // 2. Await the boolean response from the AuthProvider
                      final bool success = await context.read<AuthProvider>().login(
                        _emailController.text,
                        _passwordController.text,
                      );

                      // 3. Evaluate the result and ensure the widget is still active in memory
                      if (success && context.mounted) {
                        // 4. Navigate to the primary dashboard, destroying the login screen in the stack
                        Navigator.pushReplacementNamed(context, '/home');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlueAccent,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('SECURE LOGIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 24),

              // Navigational trigger to the Registration Module
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () {
                      // Pushes the RegisterScreen over the LoginScreen
                      Navigator.pushNamed(context, '/register');
                    },
                    child: const Text(
                      'Register Here',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
