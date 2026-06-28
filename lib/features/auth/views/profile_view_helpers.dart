import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../models/user_model.dart';

String roleLabel(String role, SettingsProvider settings) {
  switch (role) {
    case 'ketua_peronda':
      return settings.t('Ketua Peronda');
    case 'ketua_krt':
    case 'ketua':
      return settings.t('Ketua KRT');
    case 'super_admin':
      return settings.t('Super Admin');
    case 'peronda':
    default:
      return settings.t('Peronda');
  }
}

String accountStatusLabel(AccountStatus status, SettingsProvider settings) {
  return switch (status) {
    AccountStatus.active => settings.t('active'),
    AccountStatus.pending => settings.t('pending'),
    AccountStatus.inactive => settings.t('inactive'),
  };
}

class ProfileInfoRowData {
  const ProfileInfoRowData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;
}

class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({super.key, required this.data});

  final ProfileInfoRowData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = context.watch<SettingsProvider>();
    final emptyLabel = settings.t('Tiada');
    final value = (data.value ?? '').trim().isEmpty
        ? emptyLabel
        : data.value!.trim();

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, color: colorScheme.primary, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    data.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
