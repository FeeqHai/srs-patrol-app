import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'analytics_screen.dart';
import 'admin_incident_screen.dart';

class WebDashboardLayout extends StatefulWidget {
  const WebDashboardLayout({super.key});

  @override
  State<WebDashboardLayout> createState() => _WebDashboardLayoutState();
}

class _WebDashboardLayoutState extends State<WebDashboardLayout> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const AnalyticsScreen(),
    const AdminIncidentScreen(),
    const Center(child: Text("Pengurusan Ahli (Rujuk JPNIN RT 01)", style: TextStyle(color: Colors.white70, fontSize: 24))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Admin KRT (Command Center)', style: TextStyle(fontWeight: FontWeight.bold)),
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
      body: Row(
        children: [
          // Sidebar
          NavigationRail(
            backgroundColor: const Color(0xFF1E1E1E),
            indicatorColor: Colors.indigoAccent.withValues(alpha: 0.5),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            unselectedLabelTextStyle: const TextStyle(color: Colors.white54),
            selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            unselectedIconTheme: const IconThemeData(color: Colors.white54),
            selectedIconTheme: const IconThemeData(color: Colors.indigoAccent),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Pantau'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.folder_shared),
                label: Text('Laporan'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Ahli'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.black54),
          // Main Content
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }
}
