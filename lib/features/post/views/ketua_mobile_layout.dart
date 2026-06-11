import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../../auth/providers/auth_provider.dart';
import '../../attendance/views/attendance_screen.dart';
import '../../incident/views/incident_screen.dart';
import '../../auth/views/profile_screen.dart';
import '../../dashboard/views/dashboard_screen.dart';
import '../../incident/services/incident_service.dart';
import 'admin_incident_screen.dart';

class KetuaMobileLayout extends StatefulWidget {
  const KetuaMobileLayout({super.key});

  @override
  State<KetuaMobileLayout> createState() => _KetuaMobileLayoutState();
}

class _KetuaMobileLayoutState extends State<KetuaMobileLayout> {
  int _currentIndex = 0;
  bool _isSosBroadcasting = false;

  final List<String> _pageTitles = [
    'Dashboard',
    'Suapan Insiden',
    'Laporan Peronda',
    'Pengesahan Rondaan',
  ];

  Future<void> _triggerSOS() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 32,
            ),
            SizedBox(width: 8),
            Text(
              'AMARAN SOS',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Adakah anda pasti mahu mencetuskan penggera KECEMASAN? Tindakan ini akan menghantar lokasi anda serta-merta kepada semua peronda.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'SAHKAN SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSosBroadcasting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.redAccent),
            SizedBox(height: 16),
            Text(
              'Sedang Mengesan Koordinat GPS & Menyiarkan SOS...',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    try {
      final String reporterId =
          context.read<AuthProvider>().userId ?? "UNKNOWN";

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      Position currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final IncidentService service = IncidentService();
      final String? error = await service.submitReport(
        reporterId: reporterId,
        title: 'KECEMASAN / SOS DIHANTAR',
        description: 'Peronda ini memerlukan bantuan SEGERA di koordinat ini.',
        category: 'Kecemasan',
        imageFiles: [], // Empty image list for fast SOS
        location: currentPosition,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS BERJAYA DISIARKAN!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
          // Switch to Incident Feed tab so they can see the broadcast
          setState(() {
            _currentIndex = 1;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('RALAT SOS: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GAGAL PENGESANAN GPS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSosBroadcasting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic screens array inside build to pass the callback
    final List<Widget> screens = [
      DashboardScreen(
        onNavigateToScan: () {
          setState(() {
            _currentIndex = 3;
          });
        },
      ),
      const IncidentScreen(),
      const AdminIncidentScreen(),
      const AttendanceScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),

      appBar: AppBar(
        title: Text(
          _pageTitles[_currentIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 4,
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                tooltip: 'Menu Profil',
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              );
            },
          ),
        ],
      ),

      endDrawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: Column(
          children: [
            const Expanded(
              child: SafeArea(bottom: false, child: ProfileScreen()),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF121212),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'Log Keluar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      await context.read<AuthProvider>().logout();
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      body: screens[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.lightBlueAccent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType
            .fixed, // Needed for > 3 items to show labels
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 4) {
            if (!_isSosBroadcasting) _triggerSOS();
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Insiden'),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_shared),
            label: 'Laporan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Rondaan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emergency, color: Colors.redAccent),
            label: 'SOS',
          ),
        ],
      ),
    );
  }
}
