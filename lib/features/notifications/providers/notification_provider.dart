import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({NotificationService? service})
    : _service = service ?? NotificationService();

  final NotificationService _service;
  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int? _serverUnreadCount;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<AppNotification> get newNotifications => _notifications
      .where((notification) => !notification.isRead)
      .toList(growable: false);

  List<AppNotification> get historyNotifications => _notifications
      .where((notification) => notification.isRead)
      .toList(growable: false);

  int get unreadCount => _serverUnreadCount ?? newNotifications.length;

  Future<void> fetchNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.fetchNotificationPayload();
      _notifications = result.notifications;
      _serverUnreadCount = result.unreadCount;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await _service.markRead(notificationId);
    _notifications = _notifications
        .map(
          (notification) => notification.id == notificationId
              ? notification.copyWith(isRead: true)
              : notification,
        )
        .toList(growable: false);
    _serverUnreadCount = newNotifications.length;
    notifyListeners();
  }

  Future<AppNotification?> deleteNotification(String notificationId) async {
    final index = _notifications.indexWhere(
      (notification) => notification.id == notificationId,
    );
    if (index == -1) return null;

    final removed = _notifications[index];
    _notifications = [
      ..._notifications.take(index),
      ..._notifications.skip(index + 1),
    ];
    _serverUnreadCount = newNotifications.length;
    notifyListeners();

    try {
      await _service.deleteNotification(notificationId);
      return removed;
    } catch (_) {
      _notifications = [
        ..._notifications.take(index),
        removed,
        ..._notifications.skip(index),
      ];
      _serverUnreadCount = newNotifications.length;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> clearHistory() async {
    final previous = _notifications;
    _notifications = newNotifications;
    notifyListeners();

    try {
      await _service.clearHistory();
    } catch (_) {
      _notifications = previous;
      notifyListeners();
      rethrow;
    }
  }
}
