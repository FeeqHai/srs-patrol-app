import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SRS App Mockup',
      // Enforcing a dark theme because patrollers work at night.
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueGrey,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // These are the dummy screens for your modules
  final List<Widget> _screens = [
    const AttendanceMockup(),
    const MapMockup(),
    const RadioMockup(),
    const IncidentMockup(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SRS Patrol Active', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // TODO: Navigate to Profile/Auth Module
            },
          )
        ],
      ),
      body: _screens[_currentIndex],

      // THE SOS BUTTON: Center docked so it is NEVER hidden.
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Trigger Emergency SOS Module (Audio + GPS blast)
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

      // Bottom Navigation for your core modules
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

// ==========================================
// MOCKUP SCREENS (To be moved to features/ later)
// ==========================================

class AttendanceMockup extends StatelessWidget {
  const AttendanceMockup({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text('Status: OFF DUTY', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.qr_code),
            label: const Text('SCAN QR TO CLOCK IN'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class MapMockup extends StatelessWidget {
  const MapMockup({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 80, color: Colors.lightBlue),
            SizedBox(height: 20),
            Text('Live GPS Map Placeholder\n(Google Maps integration goes here)', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class RadioMockup extends StatelessWidget {
  const RadioMockup({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('KRT Sector A Channel', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 60),
          GestureDetector(
            onTapDown: (_) { /* TODO: Start WebRTC Stream */ },
            onTapUp: (_) { /* TODO: Stop WebRTC Stream */ },
            child: Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueGrey[700],
                border: Border.all(color: Colors.lightBlueAccent, width: 4),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic, size: 80, color: Colors.white),
                  SizedBox(height: 10),
                  Text('HOLD TO SPEAK', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IncidentMockup extends StatelessWidget {
  const IncidentMockup({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.camera),
          label: const Text('SNAP NEW INCIDENT (Auto-Blur)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[800],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Recent Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.image, color: Colors.grey),
          title: const Text('Suspicious Vehicle'),
          subtitle: const Text('10 mins ago - Plates Redacted'),
          trailing: const Icon(Icons.check_circle, color: Colors.green),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.image, color: Colors.grey),
          title: const Text('Broken Streetlight'),
          subtitle: const Text('1 hour ago'),
          trailing: const Icon(Icons.check_circle, color: Colors.green),
          onTap: () {},
        ),
      ],
    );
  }
}