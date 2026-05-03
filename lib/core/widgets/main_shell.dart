// File: lib/core/widgets/main_shell.dart
import 'package:flutter/material.dart';

// We will import these screens in Step 2.
import '../../features/attendance/views/attendance_screen.dart';
import '../../features/tracking/views/map_screen.dart';
import '../../features/communication/views/radio_screen.dart';
import '../../features/incident/views/incident_screen.dart';

import 'package:provider/provider.dart';
import '../../features/auth/providers/auth_provider.dart';


class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const AttendanceScreen(),
    const MapScreen(),
    const RadioScreen(),
    const IncidentScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SRS Patrol Active', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
              // This triggers the backend sign-out.
              // The AuthGate in main.dart will instantly detect this and kick you to the Login Screen.
              context.read<AuthProvider>().logout();
            },
          )
        ],
      ),
      body: _screens[_currentIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS ALERT TRIGGERED! Sending GPS & Audio...'),
              backgroundColor: Colors.red,
            ),
          );
        },
        backgroundColor: Colors.redAccent,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.sos, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.blueGrey[900],
        selectedItemColor: Colors.lightBlueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Shift'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.mic_none), label: 'PTT'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt_outlined), label: 'Report'),
        ],
      ),
    );
  }
}