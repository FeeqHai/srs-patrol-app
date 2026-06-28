import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _squad;
  List<dynamic> _schedules = [];
  String? _error;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fetchUserSchedule();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserSchedule() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.getData(
        'schedules/get_user_schedule.php',
      );
      if (response['status'] == 'success') {
        if (mounted) {
          setState(() {
            _squad = response['squad'];
            _schedules = response['schedules'] ?? [];
            _isLoading = false;
          });
          _animationController.forward(from: 0.0);
        }
      } else {
        if (mounted) {
          setState(() {
            _error = response['message'] ?? 'Gagal memuatkan jadual.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'Ralat rangkaian: Sila pastikan sambungan internet anda aktif.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchUserSchedule,
        color: colorScheme.primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorView(settings, theme)
            : _buildContentView(settings, theme, colorScheme),
      ),
    );
  }

  Widget _buildErrorView(SettingsProvider settings, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.redAccent.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              settings.t(_error ?? 'Ralat berlaku'),
              style: TextStyle(
                fontSize: 16,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.8,
                ),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchUserSchedule,
              icon: const Icon(Icons.refresh),
              label: Text(settings.t('Cuba Lagi')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView(
    SettingsProvider settings,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final bool hasSquad = _squad != null;
    final String squadName = hasSquad
        ? _squad!['squad_name']
        : settings.t('Tiada Kumpulan');
    final authProvider = context.read<AuthProvider>();
    final String userRole = authProvider.role ?? '';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Squad Info Banner Card ---
            _buildSquadBanner(
              settings,
              theme,
              colorScheme,
              squadName,
              userRole,
              hasSquad,
            ),
            const SizedBox(height: 24),

            // --- Upcoming Shifts Header ---
            Row(
              children: [
                Icon(Icons.event_note, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  settings.t('Jadual Rondaan Akan Datang'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // --- Schedule List ---
            _schedules.isEmpty
                ? _buildEmptyState(settings, theme)
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _schedules.length,
                    itemBuilder: (context, index) {
                      final schedule = _schedules[index];
                      return AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          final double opacity = CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(
                              (index * 0.05).clamp(0.0, 0.99),
                              1.0,
                              curve: Curves.easeOut,
                            ),
                          ).value;

                          return Opacity(
                            opacity: opacity,
                            child: Transform.translate(
                              offset: Offset(0, 30 * (1.0 - opacity)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildScheduleCard(
                          settings,
                          theme,
                          colorScheme,
                          schedule,
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  void _showSquadMembersDialog(
    BuildContext context,
    SettingsProvider settings,
  ) {
    if (_squad == null || _squad!['members'] == null) return;

    final members = _squad!['members'] as List<dynamic>;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.people_outline, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _squad!['squad_name'] ?? settings.t('Kumpulan Rondaan Anda'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: members.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      settings.t('Tiada ahli dalam kumpulan ini.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final name = member['full_name'] ?? '';
                      final phone = member['phone_number'] ?? '';
                      final isLeader =
                          (member['squad_role'] ?? '')
                              .toString()
                              .toUpperCase() ==
                          'LEADER';

                      return ListTile(
                        leading: UserAvatar(
                          imageUrl: member['profile_image_url'] as String?,
                          initials: UserAvatar.initialsFromName(
                            name,
                            fallback: isLeader ? 'KP' : 'P',
                          ),
                          radius: 20,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(phone),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isLeader
                                ? colorScheme.secondary.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isLeader
                                  ? colorScheme.secondary
                                  : theme.dividerColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            isLeader
                                ? settings.t('Ketua')
                                : settings.t('Ahli (Peranan)'),
                            style: TextStyle(
                              color: isLeader
                                  ? colorScheme.secondary
                                  : theme.textTheme.bodyMedium?.color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(settings.t('Tutup')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSquadBanner(
    SettingsProvider settings,
    ThemeData theme,
    ColorScheme colorScheme,
    String squadName,
    String userRole,
    bool hasSquad,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasSquad
            ? () => _showSquadMembersDialog(context, settings)
            : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E3A8A), const Color(0xFF1D4ED8)]
                  : [const Color(0xFF0F3D87), const Color(0xFF1E40AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasSquad ? Icons.shield : Icons.shield_outlined,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.t('Kumpulan Rondaan Anda'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      squadName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (hasSquad && userRole.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.secondary.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          userRole == 'ketua_peronda'
                              ? settings.t('Ketua Peronda')
                              : settings.t('Peronda'),
                          style: TextStyle(
                            color: colorScheme.secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        settings.t('Klik untuk melihat senarai ahli'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasSquad) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                  size: 24,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(
    SettingsProvider settings,
    ThemeData theme,
    ColorScheme colorScheme,
    Map<String, dynamic> schedule,
  ) {
    final String dateStr = schedule['shift_date'] ?? '';
    final String startTime = schedule['start_time'] ?? '';
    final String endTime = schedule['end_time'] ?? '';

    // Check if the shift is today
    bool isToday = false;
    try {
      final DateTime date = DateTime.parse(dateStr);
      final DateTime now = DateTime.now();
      isToday =
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? colorScheme.primary.withValues(alpha: 0.6)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Glowing highlight bar
              Container(
                width: 6,
                color: isToday
                    ? colorScheme.secondary
                    : colorScheme.primary.withValues(alpha: 0.7),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Date and Time info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                if (isToday) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondary.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      settings.t('HARI INI'),
                                      style: TextStyle(
                                        color: colorScheme.secondary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "$startTime - $endTime",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Arrow indicator icon
                      Icon(
                        Icons.chevron_right,
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(SettingsProvider settings, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 60,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              settings.t('Tiada Jadual Ditugaskan'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              settings.t('Sila hubungi Ketua KRT untuk penetapan jadual.'),
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.6,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
