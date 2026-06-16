import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/views/profile_screen.dart';

enum GlobalMenuAction { profile, settings, logout }

class GlobalMenuButton extends StatelessWidget {
  const GlobalMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return PopupMenuButton<GlobalMenuAction>(
      icon: const Icon(Icons.more_vert),
      tooltip: settings.t('Menu'),
      onSelected: (GlobalMenuAction action) async {
        switch (action) {
          case GlobalMenuAction.profile:
            _showProfileModal(context);
            break;
          case GlobalMenuAction.settings:
            _showSettingsDialog(context);
            break;
          case GlobalMenuAction.logout:
            await context.read<AuthProvider>().logout();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<GlobalMenuAction>>[
        PopupMenuItem<GlobalMenuAction>(
          value: GlobalMenuAction.profile,
          child: Row(
            children: [
              Icon(Icons.person, color: Theme.of(context).textTheme.bodyMedium?.color),
              const SizedBox(width: 8),
              Text(settings.t('Profil')),
            ],
          ),
        ),
        PopupMenuItem<GlobalMenuAction>(
          value: GlobalMenuAction.settings,
          child: Row(
            children: [
              Icon(Icons.settings, color: Theme.of(context).textTheme.bodyMedium?.color),
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
              const Icon(Icons.logout, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text(
                settings.t('Log Keluar'),
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showProfileModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  child: ProfileScreen(), // The existing ProfileScreen
                ),
              ),
            ],
          ),
        );
      },
    );
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
              trailing: settings.locale.languageCode == 'ms' ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
              onTap: () => settings.setLanguage('ms'),
            ),
            ListTile(
              title: Text(settings.t('English')),
              trailing: settings.locale.languageCode == 'en' ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
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
