// File: lib/core/widgets/main_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/attendance/views/attendance_screen.dart';
import '../../features/incident/views/incident_screen.dart'; // FIXED: Pointing to the Feed, not the Form

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // 1. DYNAMIC ROUTING ARRAY
  final List<Widget> _screens = [
    const Center(child: Text('Dashboard Module Offline', style: TextStyle(fontSize: 18, color: Colors.white70))),
    const IncidentScreen(), // The Feed (which contains the FAB to open the Report Form)
    const AttendanceScreen(),
  ];

  // 2. DYNAMIC TITLE MAPPING (Aligned perfectly with _screens indices)
  final List<String> _pageTitles = [
    'Dashboard Utama',
    'Suapan Insiden',
    'Pengesahan Rondaan'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      
      // 3. THE DYNAMIC GLOBAL HEADER
      appBar: AppBar(
        title: Text(
          _pageTitles[_currentIndex], 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)
        ),
        backgroundColor: const Color(0xFF1E1E1E), // Elevated Dark Theme surface
        elevation: 4,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Log Keluar',
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          )
        ],
      ),
      
      body: _screens[_currentIndex],
      
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.lightBlueAccent,
        unselectedItemColor: Colors.white54,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Utama'),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Insiden'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Rondaan'),
        ],
      ),
    );
  }
}