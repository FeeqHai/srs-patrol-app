import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/attendance/views/attendance_screen.dart';
import '../../features/incident/views/incident_screen.dart';
import '../../features/dashboard/views/dashboard_screen.dart';
import '../../features/dashboard/views/schedule_screen.dart';
import '../../features/incident/services/incident_service.dart';
import '../providers/settings_provider.dart';
import 'responsive_shell.dart';
import 'global_menu_button.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _isSosBroadcasting = false;
  
  final List<String> _pageTitles = [
    'Dashboard',
    'Jadual Rondaan',
    'Log Insiden',
    'Pengesahan Rondaan'
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }


  Future<void> _triggerSOS() async {
    final settings = context.read<SettingsProvider>();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogTextColor = Theme.of(context).textTheme.bodyMedium?.color;
        return AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
            const SizedBox(width: 8),
            Text(settings.t('AMARAN SOS'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          settings.t('Adakah anda pasti mahu mencetuskan penggera KECEMASAN?'),
          style: TextStyle(color: dialogTextColor?.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(settings.t('Batal'), style: TextStyle(color: dialogTextColor?.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(settings.t('SAHKAN SOS'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
      },
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isSosBroadcasting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              settings.t('Sedang Mengesan GPS & Menyiarkan SOS...'),
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    try {
      if (!mounted) return;
      final String reporterId = context.read<AuthProvider>().userId ?? "UNKNOWN";
      
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
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      );

      final IncidentService service = IncidentService();
      final String? error = await service.submitReport(
        reporterId: reporterId,
        title: 'KECEMASAN / SOS DIHANTAR',
        description: 'Peronda ini memerlukan bantuan SEGERA di koordinat ini.',
        category: 'Kecemasan',
        locationName: 'Lokasi GPS Semasa',
        reportedTo: 'Polis',
        imageFiles: [], // Empty image list for fast SOS
        location: currentPosition,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(settings.t('SOS BERJAYA DISIARKAN!')), backgroundColor: Colors.green, duration: const Duration(seconds: 4)),
          );
          // Switch to Incident Feed tab so they can see the broadcast
          setState(() {
            _currentIndex = 1;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${settings.t('RALAT SOS')}: $error'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${settings.t('GAGAL PENGESANAN GPS')}: $e'), backgroundColor: Colors.red),
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
      const ScheduleScreen(),
      const IncidentScreen(),
      AttendanceScreen(
        onNavigateToDashboard: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      ),
    ];

    final settings = context.watch<SettingsProvider>();

    return ResponsiveShell(
      currentIndex: _currentIndex,
      onIndexChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      screens: screens,
      items: [
        NavigationItem(icon: Icons.dashboard, label: settings.t('Dashboard')),
        NavigationItem(icon: Icons.calendar_month, label: settings.t('Jadual Rondaan')),
        NavigationItem(icon: Icons.warning, label: settings.t('Insiden')),
        NavigationItem(icon: Icons.qr_code_scanner, label: settings.t('Rondaan')),
      ],
      onSosPressed: _triggerSOS,
      isSosBroadcasting: _isSosBroadcasting,
      title: settings.t(_pageTitles[_currentIndex]),
      actions: const [GlobalMenuButton()],
    );
  }
}