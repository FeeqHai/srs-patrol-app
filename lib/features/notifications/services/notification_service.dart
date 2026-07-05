import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/logger.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/app_notification.dart';

class NotificationFetchResult {
  const NotificationFetchResult({
    required this.notifications,
    required this.unreadCount,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _downloadChannel = MethodChannel(
    'srs_app/downloads',
  );
  Timer? _pollingTimer;
  bool _isInitialized = false;
  final Set<String> _shownLocalNotificationIds = {};

  Future<void> initialize() async {
    if (_isInitialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _localNotificationsPlugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationPayload(response.payload);
      },
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    final launchDetails = await _localNotificationsPlugin
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _handleNotificationPayload(launchDetails?.notificationResponse?.payload);
    }

    final prefs = await SharedPreferences.getInstance();
    _shownLocalNotificationIds.addAll(
      prefs.getStringList('shown_notification_ids') ?? const [],
    );

    _isInitialized = true;
  }

  Future<void> showDownloadCompleteNotification({
    required String filePath,
    required String fileName,
  }) async {
    await initialize();

    const android = AndroidNotificationDetails(
      'srs_download_channel',
      'Download Notifications',
      channelDescription: 'Saved report and document download notifications',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Download complete',
    );
    const details = NotificationDetails(android: android);
    await _localNotificationsPlugin.show(
      id: filePath.hashCode & 0x7fffffff,
      title: 'Fail dimuat turun',
      body: '$fileName disimpan. Tekan untuk buka fail.',
      notificationDetails: details,
      payload: 'download-file|$filePath',
    );
  }

  Future<void> _handleNotificationPayload(String? payload) async {
    final value = payload ?? '';
    const prefix = 'download-file|';
    if (!value.startsWith(prefix)) return;

    final filePath = value.substring(prefix.length);
    if (filePath.isEmpty) return;

    try {
      await _downloadChannel.invokeMethod<bool>('openDownloadedFile', {
        'target': filePath,
      });
    } catch (error, stackTrace) {
      appLogger.w(
        'Unable to open downloaded file from notification',
        error: error,
        stackTrace: stackTrace,
      );
    }
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

  Future<NotificationFetchResult> fetchNotificationPayload() async {
    final response = await ApiClient.getData(
      'notifications/get_notifications.php',
    );
    if (response['status'] != 'success') {
      throw Exception(response['message'] ?? 'Unable to load notifications.');
    }

    final rawData = response['data'];
    final List<dynamic> data = rawData is Map<String, dynamic>
        ? rawData['notifications'] as List<dynamic>? ?? const []
        : rawData as List<dynamic>? ?? const [];
    final notifications = data
        .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
        .toList();
    final unreadCount = rawData is Map<String, dynamic>
        ? int.tryParse(rawData['unread_count']?.toString() ?? '') ??
              notifications.where((item) => !item.isRead).length
        : notifications.where((item) => !item.isRead).length;

    return NotificationFetchResult(
      notifications: notifications,
      unreadCount: unreadCount,
    );
  }

  Future<List<AppNotification>> fetchNotifications() async {
    final result = await fetchNotificationPayload();
    return result.notifications;
  }

  Future<void> markRead(String notificationId) async {
    await ApiClient.postData('notifications/mark_read.php', {
      'notification_id': notificationId,
    });
  }

  Future<void> deleteNotification(String notificationId) async {
    await ApiClient.postData('notifications/delete_notification.php', {
      'notification_id': notificationId,
    });
  }

  Future<void> clearHistory() async {
    await ApiClient.postData(
      'notifications/clear_history.php',
      <String, String>{},
    );
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
