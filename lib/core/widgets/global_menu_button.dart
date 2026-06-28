import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/views/account_screen.dart';
import '../providers/settings_provider.dart';
import 'user_avatar.dart';

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Tooltip(
        message: settings.t('account'),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountScreen()),
            );
          },
          child: UserAvatar(
            imageUrl: auth.profileImageUrl,
            initials: initials,
            radius: 18,
          ),
        ),
      ),
    );
  }
}
