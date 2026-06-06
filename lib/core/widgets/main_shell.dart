import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/incident/views/incident_report_screen.dart';

// 1. INJECT THE MISSING IMPORT
import '../../features/attendance/views/attendance_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({Key? key}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // 2. UPDATE THE ROUTING ARRAY
  final List<Widget> _screens = [
    const Center(child: Text('Dashboard Module Offline', style: TextStyle(fontSize: 18))),
    const IncidentReportScreen(),
    const AttendanceScreen(), // The placeholder is replaced with the active module
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SRS Patrol'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Terminate Session',
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
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Incident'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Patrol'),
        ],
      ),
    );
  }
}