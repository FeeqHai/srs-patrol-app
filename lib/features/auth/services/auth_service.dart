// File: lib/features/auth/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream to listen to auth state changes (logged in vs logged out)
  Stream<User?> get userStream => _auth.authStateChanges();

  // The Login Function
  Future<UserCredential?> loginWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      // In a production app, you would handle specific error codes here
      throw Exception(e.message ?? 'An unknown authentication error occurred.');
    }
  }

  // The Logout Function
  Future<void> logout() async {
    await _auth.signOut();
  }
}