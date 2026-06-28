import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../incident/services/incident_service.dart';
import '../../incident/views/incident_detail_screen.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifications = await _notificationService.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    await _notificationService.markRead(notification.id);
    if (!mounted) return;
    setState(() {
      _notifications = _notifications
          .map(
            (item) => item.id == notification.id
                ? AppNotification(
                    id: item.id,
                    type: item.type,
                    title: item.title,
                    body: item.body,
                    relatedId: item.relatedId,
                    isRead: true,
                    createdAt: item.createdAt,
                  )
                : item,
          )
          .toList();
    });

    final relatedId = notification.relatedId;
    if (relatedId == null || relatedId.isEmpty) return;

    if (notification.type == 'daily_note' || notification.type == 'sos') {
      try {
        final incidents = await IncidentService().fetchAllIncidents();
        final match = incidents.cast<Map<String, dynamic>?>().firstWhere(
          (incident) => incident?['id']?.toString() == relatedId,
          orElse: () => null,
        );
        if (!mounted) return;
        if (match == null) {
          _showSnack(context.read<SettingsProvider>().t('Tiada data profil'));
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IncidentDetailScreen(incident: match),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        _showSnack(error.toString());
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('notifications')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorState(message: _error!, onRetry: _loadNotifications)
            : _notifications.isEmpty
            ? _EmptyState(message: settings.t('no_notifications'))
            : RefreshIndicator(
                onRefresh: _loadNotifications,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final isSos = notification.type == 'sos';
                    final color = isSos
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary;
                    return Material(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openNotification(notification),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: notification.isRead
                                  ? theme.dividerColor.withValues(alpha: 0.12)
                                  : color.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isSos
                                      ? Icons.emergency_outlined
                                      : Icons.edit_note_outlined,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _localizedTitle(
                                              notification,
                                              settings,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                        if (!notification.isRead)
                                          Container(
                                            width: 9,
                                            height: 9,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notification.body,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.68),
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      notification.createdAt,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  String _localizedTitle(
    AppNotification notification,
    SettingsProvider settings,
  ) {
    if (notification.type == 'daily_note') return settings.t('new_daily_note');
    if (notification.type == 'sos') return settings.t('sos_alerts');
    return notification.title;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              color: colorScheme.onSurface.withValues(alpha: 0.45),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colorScheme.error, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(settings.t('Cuba Semula')),
            ),
          ],
        ),
      ),
    );
  }
}
