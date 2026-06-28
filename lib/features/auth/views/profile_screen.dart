import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/user_avatar.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _isLoading = true;
  bool _isUploadingImage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final settings = context.read<SettingsProvider>();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await _authService.fetchProfile();
      if (!mounted) return;
      await context.read<AuthProvider>().updateCurrentUserProfile(user);
      if (!mounted) return;
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      appLogger.e('Profile fetch failed', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _error = settings.t('Gagal memuat turun profil.');
        _isLoading = false;
      });
    }
  }

  Future<void> _chooseProfileImage() async {
    final settings = context.read<SettingsProvider>();
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (image == null || !mounted) return;

    final lowerName = image.name.toLowerCase();
    final isSupported =
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp');
    if (!isSupported) {
      _showSnack(settings.t('invalid_image'), isError: true);
      return;
    }

    setState(() => _isUploadingImage = true);
    final authProvider = context.read<AuthProvider>();
    final previousUser = _user;
    final success = await authProvider.updateProfilePhoto(image);

    if (!mounted) return;
    if (success) {
      final updatedUser = (_user ?? previousUser)?.copyWith(
        profileImageUrl: authProvider.profileImageUrl,
      );
      setState(() {
        if (updatedUser != null) _user = updatedUser;
        _isUploadingImage = false;
      });
      _showSnack(settings.t('photo_upload_success'));
      await _fetchProfile();
    } else {
      setState(() => _isUploadingImage = false);
      _showSnack(
        authProvider.errorMessage ?? settings.t('photo_upload_failed'),
        isError: true,
      );
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(settings.t('profile')), centerTitle: true),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorState(message: _error!, onRetry: _fetchProfile)
            : _user == null
            ? Center(child: Text(settings.t('Tiada data profil')))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth < 640
                      ? 16.0
                      : 24.0;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 580),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ProfileHeader(
                              user: _user!,
                              isUploading: _isUploadingImage,
                              onAvatarTap: _chooseProfileImage,
                            ),
                            const SizedBox(height: 18),
                            _AccountStatusCard(user: _user!),
                            const SizedBox(height: 24),
                            Text(
                              settings.t('personal_information'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _PersonalInformationCard(user: _user!),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.isUploading,
    required this.onAvatarTap,
  });

  final UserModel user;
  final bool isUploading;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          UserAvatar(
            imageUrl: user.effectiveProfileImageUrl,
            initials: UserAvatar.initialsFromName(user.fullName),
            radius: 58,
            showEditBadge: true,
            isLoading: isUploading,
            onTap: onAvatarTap,
            tooltip: settings.t('change_profile_photo'),
          ),
          const SizedBox(height: 16),
          Text(
            user.fullName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          if ((user.email ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              user.email!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: colorScheme.secondary.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _roleLabel(user.role, settings).toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountStatusCard extends StatelessWidget {
  const _AccountStatusCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusText = _statusLabel(user.accountStatusEnum, settings);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AccountColumn(label: settings.t('user_id'), value: user.id),
          ),
          Container(
            width: 1,
            height: 46,
            color: colorScheme.onPrimary.withValues(alpha: 0.22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  settings.t('account_status'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 7),
                _StatusChip(status: user.accountStatusEnum, label: statusText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountColumn extends StatelessWidget {
  const _AccountColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onPrimary.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 7),
        Tooltip(
          message: value,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});

  final AccountStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = switch (status) {
      AccountStatus.active => colorScheme.secondary,
      AccountStatus.pending => colorScheme.secondary.withValues(alpha: 0.82),
      AccountStatus.inactive => colorScheme.error,
    };
    final foreground = status == AccountStatus.inactive
        ? colorScheme.onError
        : colorScheme.onSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PersonalInformationCard extends StatelessWidget {
  const _PersonalInformationCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final rows = <_InfoRowData>[
      _InfoRowData(
        icon: Icons.badge_outlined,
        label: settings.t('ic_number'),
        value: user.icNumber,
      ),
      _InfoRowData(
        icon: Icons.phone_outlined,
        label: settings.t('phone_number'),
        value: user.phoneNumber,
      ),
      _InfoRowData(
        icon: Icons.mail_outline,
        label: settings.t('email'),
        value: user.email,
      ),
      _InfoRowData(
        icon: Icons.admin_panel_settings_outlined,
        label: settings.t('role'),
        value: _roleLabel(user.role, settings),
      ),
      _InfoRowData(
        icon: Icons.map_outlined,
        label: settings.t('state'),
        value: user.stateName,
      ),
      _InfoRowData(
        icon: Icons.location_city_outlined,
        label: settings.t('district'),
        value: user.districtName,
      ),
      _InfoRowData(
        icon: Icons.place_outlined,
        label: settings.t('zone'),
        value: user.zoneName ?? user.districtZone,
      ),
      if ((user.squadName ?? '').trim().isNotEmpty)
        _InfoRowData(
          icon: Icons.groups_2_outlined,
          label: settings.t('squad'),
          value: user.squadName,
        ),
      _InfoRowData(
        icon: Icons.verified_user_outlined,
        label: settings.t('account_status'),
        value: _statusLabel(user.accountStatusEnum, settings),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _InfoRow(data: rows[i]),
            if (i != rows.length - 1)
              Divider(
                height: 1,
                indent: 64,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.data});

  final _InfoRowData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final value = (data.value ?? '').trim().isEmpty
        ? context.watch<SettingsProvider>().t('Tiada')
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

class _InfoRowData {
  const _InfoRowData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;
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
            Icon(Icons.error_outline, color: colorScheme.error, size: 52),
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

String _roleLabel(String role, SettingsProvider settings) {
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

String _statusLabel(AccountStatus status, SettingsProvider settings) {
  return switch (status) {
    AccountStatus.active => settings.t('active'),
    AccountStatus.pending => settings.t('pending'),
    AccountStatus.inactive => settings.t('inactive'),
  };
}
