import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import '../constants/api_constants.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class SosAlertService {
  static final SosAlertService _instance = SosAlertService._internal();
  factory SosAlertService() => _instance;
  SosAlertService._internal();

  Timer? _pollingTimer;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Track notified SOS IDs to avoid spamming the same alert
  final Set<String> _notifiedSosIds = {};
  
  // We need a navigator key to show dialogs globally
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _localNotificationsPlugin.initialize(settings: initializationSettings);
    _isInitialized = true;
  }

  void startPolling(BuildContext context) {
    if (_pollingTimer != null && _pollingTimer!.isActive) return;
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pollForSos(context);
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _pollForSos(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) return;

    try {
      final currentUserId = authProvider.userId;
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}incidents/check_sos.php?exclude_user=$currentUserId'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final List<dynamic> sosList = data['data'];
          
          for (var sos in sosList) {
            final sosId = sos['id'].toString();
            if (!_notifiedSosIds.contains(sosId)) {
              _notifiedSosIds.add(sosId);
              _triggerSosAlert(sos);
            }
          }
        }
      }
    } catch (e) {
      // Silently ignore network errors on background polling
    }
  }

  Future<void> _triggerSosAlert(Map<String, dynamic> sos) async {
    final String name = sos['full_name'] ?? 'Seseorang';
    final String location = sos['location_name'] ?? 'Lokasi tidak diketahui';
    final String time = sos['created_at'] ?? '';
    final String message = '$name memerlukan bantuan SEGERA di $location! ($time)';

    // 1. Vibrate (if available)
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      // Vibrate for 3 seconds pattern
      Vibration.vibrate(pattern: [500, 1000, 500, 1000, 500, 1000]);
    }

    // 2. System Notification
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'srs_sos_channel', 
      'SOS Alerts',
      channelDescription: 'Emergency SOS Alerts from Patrollers',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'KECEMASAN SOS',
      color: Colors.red,
      enableVibration: true,
      playSound: true,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _localNotificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: 'AMARAN KECEMASAN (SOS)',
      body: message,
      notificationDetails: platformChannelSpecifics,
    );

    // 3. App Dialog Overlay
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: false, // Must explicitly tap acknowledge
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.red.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.red, width: 3)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AMARAN KECEMASAN!',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name telah menekan butang SOS dan memerlukan bantuan segera.',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Lokasi:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text(location, style: const TextStyle(fontSize: 15, color: Colors.black)),
                      const SizedBox(height: 8),
                      const Text('Masa:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text(time, style: const TextStyle(fontSize: 15, color: Colors.black)),
                    ],
                  ),
                )
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text('SAH / TUTUP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          );
        },
      );
    }
  }
}
