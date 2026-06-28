import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/logger.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/app_notification.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Timer? _pollingTimer;
  bool _isInitialized = false;
  final Set<String> _shownLocalNotificationIds = {};

  Future<void> initialize() async {
    if (_isInitialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _localNotificationsPlugin.initialize(settings: settings);

    final prefs = await SharedPreferences.getInstance();
    _shownLocalNotificationIds.addAll(
      prefs.getStringList('shown_notification_ids') ?? const [],
    );

    _isInitialized = true;
  }

  void startPolling(BuildContext context) {
    if (_pollingTimer != null && _pollingTimer!.isActive) return;
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _pollForDailyNotes(context);
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<List<AppNotification>> fetchNotifications() async {
    final response = await ApiClient.getData(
      'notifications/get_notifications.php',
    );
    if (response['status'] != 'success') {
      throw Exception(response['message'] ?? 'Unable to load notifications.');
    }

    final data = response['data'] as List<dynamic>? ?? const [];
    return data
        .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String notificationId) async {
    await ApiClient.postData('notifications/mark_read.php', {
      'id': notificationId,
    });
  }

  Future<void> _pollForDailyNotes(BuildContext context) async {
    if (!context.mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;

    final settings = context.read<SettingsProvider>();
    if (!settings.allowExternalNotifications ||
        !settings.dailyNoteNotifications) {
      return;
    }

    try {
      final notifications = await fetchNotifications();
      for (final notification in notifications) {
        if (notification.isRead ||
            notification.type != 'daily_note' ||
            _shownLocalNotificationIds.contains(notification.id)) {
          continue;
        }
        await _showDailyNoteNotification(notification);
        _shownLocalNotificationIds.add(notification.id);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'shown_notification_ids',
        _shownLocalNotificationIds.take(250).toList(),
      );
    } catch (error, stackTrace) {
      appLogger.w(
        'Unable to poll app notifications',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _showDailyNoteNotification(AppNotification notification) async {
    const android = AndroidNotificationDetails(
      'srs_daily_note_channel',
      'Daily Note Notifications',
      channelDescription: 'Daily note updates for Ketua KRT',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: android);
    await _localNotificationsPlugin.show(
      id: notification.id.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
    );
  }
}
