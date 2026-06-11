import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'admin_incident_screen.dart';
import 'qr_generator_screen.dart';

class AdminMobileLayout extends StatefulWidget {
  const AdminMobileLayout({super.key});

  @override
  State<AdminMobileLayout> createState() => _AdminMobileLayoutState();
}

class _AdminMobileLayoutState extends State<AdminMobileLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const QrGeneratorScreen(),
    const AdminIncidentScreen(),
    const Center(child: Text("Pengurusan Ahli", style: TextStyle(color: Colors.white70, fontSize: 18))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Admin KRT', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.indigoAccent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed, // To show 4 items properly
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Jana QR'),
          BottomNavigationBarItem(icon: Icon(Icons.folder_shared), label: 'Laporan'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Ahli'),
        ],
      ),
    );
  }
}
