import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/user_avatar.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import 'profile_view_helpers.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _isLoading = true;
  bool _isChangingPhoto = false;
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
    } catch (error, stackTrace) {
      appLogger.e(
        'Personal information fetch failed',
        error: error,
        stackTrace: stackTrace,
      );
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

    setState(() => _isChangingPhoto = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.updateProfilePhoto(image);

    if (!mounted) return;
    if (success) {
      setState(() {
        _user = _user?.copyWith(profileImageUrl: authProvider.profileImageUrl);
        _isChangingPhoto = false;
      });
      _showSnack(settings.t('photo_upload_success'));
      await _fetchProfile();
    } else {
      setState(() => _isChangingPhoto = false);
      _showSnack(
        authProvider.errorMessage ?? settings.t('photo_upload_failed'),
        isError: true,
      );
    }
  }

  Future<void> _confirmRemovePhoto() async {
    final settings = context.read<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(settings.t('remove_profile_photo')),
        content: Text(settings.t('remove_profile_photo_confirmation')),
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
            child: Text(settings.t('remove_profile_photo')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isChangingPhoto = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.removeProfilePhoto();
    if (!mounted) return;

    if (success) {
      setState(() {
        _user = _user?.copyWith(profileImageUrl: '', profileImagePath: '');
        _isChangingPhoto = false;
      });
      _showSnack(settings.t('photo_remove_success'));
      await _fetchProfile();
    } else {
      setState(() => _isChangingPhoto = false);
      _showSnack(
        authProvider.errorMessage ?? settings.t('photo_remove_failed'),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('personal_information')),
        centerTitle: true,
      ),
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
                      28,
                      horizontalPadding,
                      32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 580),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PhotoHeader(
                              user: _user!,
                              isChangingPhoto: _isChangingPhoto,
                              onChangePhoto: _chooseProfileImage,
                              onRemovePhoto:
                                  (_user!.effectiveProfileImageUrl ?? '')
                                      .trim()
                                      .isEmpty
                                  ? null
                                  : _confirmRemovePhoto,
                            ),
                            const SizedBox(height: 18),
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

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({
    required this.user,
    required this.isChangingPhoto,
    required this.onChangePhoto,
    required this.onRemovePhoto,
  });

  final UserModel user;
  final bool isChangingPhoto;
  final VoidCallback onChangePhoto;
  final VoidCallback? onRemovePhoto;

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
      ),
      child: Column(
        children: [
          UserAvatar(
            imageUrl: user.effectiveProfileImageUrl,
            initials: UserAvatar.initialsFromName(user.fullName),
            radius: 58,
            showEditBadge: true,
            isLoading: isChangingPhoto,
            onTap: onChangePhoto,
            tooltip: settings.t('change_profile_photo'),
          ),
          const SizedBox(height: 16),
          Text(
            settings.t('profile_photo'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: isChangingPhoto ? null : onChangePhoto,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(settings.t('change_profile_photo')),
              ),
              if (onRemovePhoto != null)
                TextButton.icon(
                  onPressed: isChangingPhoto ? null : onRemovePhoto,
                  icon: Icon(Icons.delete_outline, color: colorScheme.error),
                  label: Text(
                    settings.t('remove_profile_photo'),
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
            ],
          ),
        ],
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
    final rows = <ProfileInfoRowData>[
      ProfileInfoRowData(
        icon: Icons.person_outline,
        label: settings.t('Nama Penuh'),
        value: user.fullName,
      ),
      ProfileInfoRowData(
        icon: Icons.badge_outlined,
        label: settings.t('ic_number'),
        value: user.icNumber,
      ),
      ProfileInfoRowData(
        icon: Icons.phone_outlined,
        label: settings.t('phone_number'),
        value: user.phoneNumber,
      ),
      ProfileInfoRowData(
        icon: Icons.mail_outline,
        label: settings.t('email'),
        value: user.email,
      ),
      ProfileInfoRowData(
        icon: Icons.admin_panel_settings_outlined,
        label: settings.t('role'),
        value: roleLabel(user.role, settings),
      ),
      ProfileInfoRowData(
        icon: Icons.map_outlined,
        label: settings.t('state'),
        value: user.stateName,
      ),
      ProfileInfoRowData(
        icon: Icons.location_city_outlined,
        label: settings.t('district'),
        value: user.districtName,
      ),
      ProfileInfoRowData(
        icon: Icons.place_outlined,
        label: settings.t('zone'),
        value: user.zoneName ?? user.districtZone,
      ),
      if ((user.squadName ?? '').trim().isNotEmpty)
        ProfileInfoRowData(
          icon: Icons.groups_2_outlined,
          label: settings.t('squad'),
          value: user.squadName,
        ),
      ProfileInfoRowData(
        icon: Icons.verified_user_outlined,
        label: settings.t('account_status'),
        value: accountStatusLabel(user.accountStatusEnum, settings),
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
            ProfileInfoRow(data: rows[i]),
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
