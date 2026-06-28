import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/views/profile_screen.dart';
import 'user_avatar.dart';

enum GlobalMenuAction { profile, settings, logout }

class GlobalMenuButton extends StatelessWidget {
  const GlobalMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final initials = UserAvatar.initialsFromName(
      auth.fullName,
      fallback: auth.role == 'ketua_krt' ? 'KK' : 'U',
    );

    return PopupMenuButton<GlobalMenuAction>(
      tooltip: settings.t('profile'),
      offset: const Offset(0, 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: UserAvatar(
          imageUrl: auth.profileImageUrl,
          initials: initials,
          radius: 18,
        ),
      ),
      onSelected: (GlobalMenuAction action) async {
        switch (action) {
          case GlobalMenuAction.profile:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
            break;
          case GlobalMenuAction.settings:
            _showSettingsDialog(context);
            break;
          case GlobalMenuAction.logout:
            await _confirmAndLogout(context);
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<GlobalMenuAction>>[
        PopupMenuItem<GlobalMenuAction>(
          value: GlobalMenuAction.profile,
          child: Row(
            children: [
              Icon(
                Icons.person,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              const SizedBox(width: 8),
              Text(settings.t('profile')),
            ],
          ),
        ),
        PopupMenuItem<GlobalMenuAction>(
          value: GlobalMenuAction.settings,
          child: Row(
            children: [
              Icon(
                Icons.settings,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              const SizedBox(width: 8),
              Text(settings.t('Tetapan')),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<GlobalMenuAction>(
          value: GlobalMenuAction.logout,
          child: Row(
            children: [
              Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Text(
                settings.t('logout'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndLogout(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(settings.t('logout_confirmation_title')),
        content: Text(settings.t('logout_confirmation_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(settings.t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(settings.t('confirm_logout')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await context.read<AuthProvider>().logout();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return const _SettingsDialogContent();
      },
    );
  }
}

class _SettingsDialogContent extends StatelessWidget {
  const _SettingsDialogContent();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return AlertDialog(
      title: Text(settings.t('Tetapan')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settings.t('Bahasa'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(settings.t('Bahasa Melayu')),
              trailing: settings.locale.languageCode == 'ms'
                  ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                  : null,
              onTap: () => settings.setLanguage('ms'),
            ),
            ListTile(
              title: Text(settings.t('English')),
              trailing: settings.locale.languageCode == 'en'
                  ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                  : null,
              onTap: () => settings.setLanguage('en'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(settings.t('Tutup')),
        ),
      ],
    );
  }
}
