import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart';
import '../../core/constants/api_constants.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/attendance/views/attendance_screen.dart';
import '../../features/incident/views/incident_screen.dart';
import '../../features/auth/views/profile_screen.dart';
import '../../features/dashboard/views/dashboard_screen.dart';
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
  
  Timer? _sosTimer;
  DateTime? _lastSosCheck;
  bool _isShowingSosDialog = false;

  final List<String> _pageTitles = [
    'Dashboard',
    'Log Insiden',
    'Pengesahan Rondaan'
  ];

  @override
  void initState() {
    super.initState();
    _lastSosCheck = DateTime.now();
    _sosTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollSOS());
  }

  @override
  void dispose() {
    _sosTimer?.cancel();
    super.dispose();
  }

  Set<String> _notifiedSosIds = {};

  Future<void> _pollSOS() async {
    if (!mounted) return;
    
    // Only poll SOS if shift is active
    final prefs = await SharedPreferences.getInstance();
    final bool isShiftActive = prefs.getBool('shiftActive') ?? false;
    if (!isShiftActive) return;

    final currentUserId = context.read<AuthProvider>().userId;
    if (currentUserId == null) return;
    
    try {
      String timeStr = _lastSosCheck!.toIso8601String().replaceAll('T', ' ').split('.')[0]; 
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}incidents/check_sos.php?exclude_user=$currentUserId&after=$timeStr'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'].isNotEmpty) {
          final sosList = data['data'] as List<dynamic>;
          for (var sos in sosList) {
            String sosId = sos['id'].toString();
            if (!_notifiedSosIds.contains(sosId)) {
              _notifiedSosIds.add(sosId);
              _lastSosCheck = DateTime.now();
              
              // Trigger local notification outside the app
              _triggerLocalNotification(sos);

              // Show inside app dialog if not already showing one
              if (!_isShowingSosDialog) {
                _showSosAlert(sos);
              }
            }
          }
        }
      }
    } catch (e) {
      // Silently ignore network errors for background polling
    }
  }

  Future<void> _triggerLocalNotification(Map<String, dynamic> sos) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'sos_channel', 'SOS Emergencies',
      channelDescription: 'Emergency alerts from other patrollers',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'SOS',
      color: Colors.red,
      playSound: true,
      enableVibration: true,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: 'KECEMASAN (SOS)!',
      body: '${sos['full_name']} memerlukan bantuan!',
      notificationDetails: platformChannelSpecifics,
    );
  }

  void _showSosAlert(Map<String, dynamic> sosData) {
    if (!mounted) return;
    _isShowingSosDialog = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 40),
            SizedBox(width: 10),
            Text('KECEMASAN!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Seorang peronda memerlukan bantuan SEGERA!', style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),
            Text('Peronda: ${sosData['full_name'] ?? 'Tidak Diketahui'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Masa: ${sosData['created_at']}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Lokasi: ${sosData['latitude'] ?? 'N/A'}, ${sosData['longitude'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          if (sosData['latitude'] != null && sosData['longitude'] != null)
            ElevatedButton(
              onPressed: () async {
                final lat = sosData['latitude'];
                final lng = sosData['longitude'];
                final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              child: const Text('GOOGLE MAPS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _isShowingSosDialog = false;
              setState(() {
                _currentIndex = 1; // Route to Incident feed
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red[900]),
            child: const Text('LIHAT LOG', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
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
            _currentIndex = 2;
          });
        },
      ),
      const IncidentScreen(),
      const AttendanceScreen(),
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