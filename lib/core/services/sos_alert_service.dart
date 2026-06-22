import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final Map<String, String> headers = {};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}incidents/check_sos.php?exclude_user=$currentUserId'),
        headers: headers,
      );
      
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
    final String sosId = sos['id']?.toString() ?? '';
    final latitude = double.tryParse(sos['latitude']?.toString() ?? '');
    final longitude = double.tryParse(sos['longitude']?.toString() ?? '');
    final mapsUri = latitude != null && longitude != null
        ? Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
          )
        : null;
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
    
    try {
      await _localNotificationsPlugin.show(
        id: DateTime.now().millisecond,
        title: 'AMARAN KECEMASAN (SOS)',
        body: message,
        notificationDetails: platformChannelSpecifics,
      );
    } catch (error) {
      // Web notifications may be blocked until the user grants browser permission.
      debugPrint('Unable to show SOS system notification: $error');
    }

    // 3. App Dialog Overlay
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: false, // Must explicitly tap acknowledge
        builder: (BuildContext context) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Material(
                color: const Color(0xFFFFEEF0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.redAccent, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.redAccent,
                            size: 34,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'AMARAN KECEMASAN!',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '$name telah menekan butang SOS dan memerlukan bantuan segera.',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _SosDetailRow(
                              icon: Icons.location_on_outlined,
                              label: 'Lokasi',
                              value: location,
                            ),
                            if (mapsUri != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => _openGoogleMaps(mapsUri),
                                  icon: const Icon(Icons.map_outlined),
                                  label: const Text('Open Google Maps'),
                                ),
                              ),
                            ],
                            const Divider(height: 24),
                            _SosDetailRow(
                              icon: Icons.schedule_outlined,
                              label: 'Masa',
                              value: time,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            if (sosId.isNotEmpty) {
                              _acknowledgeSos(sosId);
                            }
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text(
                            'SAH & TUTUP',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _openGoogleMaps(Uri mapsUri) async {
    try {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Unable to open SOS location: $error');
    }
  }

  Future<void> _acknowledgeSos(String incidentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}incidents/acknowledge_sos.php'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({'incident_id': incidentId}),
      );
    } catch (error) {
      debugPrint('Unable to acknowledge SOS alert: $error');
    }
  }
}

class _SosDetailRow extends StatelessWidget {
  const _SosDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.redAccent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
