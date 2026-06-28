import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../incident/services/incident_service.dart';
import '../../incident/views/incident_detail_screen.dart';
import '../models/app_notification.dart';
import '../providers/notification_provider.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openNotification(AppNotification notification) async {
    final provider = context.read<NotificationProvider>();
    final settings = context.read<SettingsProvider>();

    if (!notification.isRead) {
      await provider.markAsRead(notification.id);
    }

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
          _showSnack(settings.t('Tiada data profil'));
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

  Future<void> _deleteNotification(AppNotification notification) async {
    final settings = context.read<SettingsProvider>();
    try {
      await context.read<NotificationProvider>().deleteNotification(
        notification.id,
      );
      if (!mounted) return;
      _showSnack(settings.t('notification_removed'));
    } catch (error) {
      if (!mounted) return;
      _showSnack(error.toString());
    }
  }

  Future<void> _confirmClearHistory() async {
    final settings = context.read<SettingsProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t('clear_history')),
        content: Text(settings.t('Clear all notification history?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(settings.t('Batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(settings.t('clear_all')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await context.read<NotificationProvider>().clearHistory();
      if (mounted) _showSnack(settings.t('notification_removed'));
    } catch (error) {
      if (mounted) _showSnack(error.toString());
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
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('notifications')),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Theme.of(context).colorScheme.secondary,
          tabs: [
            Tab(text: settings.t('new_notifications')),
            Tab(text: settings.t('notification_history')),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              if (_tabController.index != 1 ||
                  provider.historyNotifications.isEmpty) {
                return const SizedBox.shrink();
              }
              return TextButton(
                onPressed: _confirmClearHistory,
                child: Text(
                  settings.t('clear_all'),
                  style: const TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: provider.isLoading && provider.notifications.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.error != null && provider.notifications.isEmpty
            ? _ErrorState(
                message: provider.error!,
                onRetry: provider.fetchNotifications,
              )
            : RefreshIndicator(
                onRefresh: provider.fetchNotifications,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _NotificationList(
                      notifications: provider.newNotifications,
                      emptyMessage: settings.t('no_new_notifications'),
                      onTap: _openNotification,
                      onDelete: _deleteNotification,
                    ),
                    _NotificationList(
                      notifications: provider.historyNotifications,
                      emptyMessage: settings.t('no_notification_history'),
                      onTap: _openNotification,
                      onDelete: _deleteNotification,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.notifications,
    required this.emptyMessage,
    required this.onTap,
    required this.onDelete,
  });

  final List<AppNotification> notifications;
  final String emptyMessage;
  final ValueChanged<AppNotification> onTap;
  final ValueChanged<AppNotification> onDelete;

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [_EmptyState(message: emptyMessage)],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return Dismissible(
          key: ValueKey(notification.id),
          direction: DismissDirection.endToStart,
          background: const SizedBox.shrink(),
          secondaryBackground: _DeleteBackground(
            label: context.read<SettingsProvider>().t('delete_notification'),
          ),
          onDismissed: (_) => onDelete(notification),
          child: _NotificationCard(
            notification: notification,
            onTap: () => onTap(notification),
          ),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final color = notification.type == 'sos'
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? theme.dividerColor.withValues(alpha: 0.12)
                  : color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconFor(notification.type), color: color),
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
                            _localizedTitle(notification, settings),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(left: 8),
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
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.68,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notification.createdAt,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
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
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'daily_note':
        return Icons.edit_note_outlined;
      case 'sos':
        return Icons.emergency_outlined;
      case 'member_transfer':
      case 'squad_member_transferred':
        return Icons.person_pin_circle_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
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

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.delete_outline, color: Colors.white),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_off_outlined,
                color: colorScheme.onSurface.withValues(alpha: 0.45),
                size: 52,
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
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
