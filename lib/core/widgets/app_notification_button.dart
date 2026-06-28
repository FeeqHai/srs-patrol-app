import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/notifications/services/notification_service.dart';
import '../../features/notifications/views/notification_screen.dart';
import '../providers/settings_provider.dart';

class AppNotificationButton extends StatelessWidget {
  const AppNotificationButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return FutureBuilder<int>(
      future: _unreadCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return IconButton(
          icon: Badge.count(
            count: count,
            isLabelVisible: count > 0,
            child: const Icon(Icons.notifications_none_rounded),
          ),
          tooltip: settings.t('notifications'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            );
          },
        );
      },
    );
  }

  Future<int> _unreadCount() async {
    try {
      final notifications = await NotificationService().fetchNotifications();
      return notifications.where((item) => !item.isRead).length;
    } catch (_) {
      return 0;
    }
  }
}
