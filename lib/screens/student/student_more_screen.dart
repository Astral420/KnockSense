import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/widgets/common/notification_icon_widget.dart';
import 'package:knocksense/widgets/common/useravatar_widget.dart';
import 'package:knocksense/provider/notification_preferences_provider.dart';
import 'package:knocksense/models/notification_preferences.dart';

final studentMoreExpandSettingsProvider = StateProvider<bool>((ref) => false);

class MorePage extends ConsumerWidget {
  const MorePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final authService = ref.read(authServiceProvider);
    final notificationPreferences = ref.watch(notificationPreferencesControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: user.when(
          data: (userData) {
            if (userData == null) {
              return const Center(child: Text('User data not found.'));
            }
            
            return Column(
              children: [
                // Header with title and role badge
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'More',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const NotificationIconWidget(
                        iconColor: Colors.black,
                      ),
                    ],
                  ),
                ),

                // Profile Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          UserAvatar(
                            radius: 35,
                            showBorder: false,
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userData.displayName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userData.role.name[0].toUpperCase() + 
                              userData.role.name.substring(1),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Menu Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    children: [
                      _buildNotificationSettingsCard(
                        context,
                        ref,
                        notificationPreferences,
                      ),
                      _buildRegularMenuItem(
                        label: 'Help',
                        svgPath: 'assets/icons/help.svg',
                        onTap: () => _handleHelp(context),
                      ),
                      _buildRegularMenuItem(
                        label: 'Logout',
                        svgPath: 'assets/icons/logout.svg',
                        onTap: () => _handleLogout(context, authService),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildNotificationSettingsCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<NotificationPreferenceState> preferences,
  ) {
    final expanded = ref.watch(studentMoreExpandSettingsProvider);
    final notifier = ref.read(notificationPreferencesControllerProvider.notifier);
    final prefs = preferences.asData?.value ?? NotificationPreferenceState.defaults;
    final isLoading = preferences.isLoading;
    final error = preferences.hasError ? preferences.error : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => ref.read(studentMoreExpandSettingsProvider.notifier).state = !expanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/bell.svg',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notification Settings',
                      style: GoogleFonts.roboto(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          if (expanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Could not load preferences. Using defaults.',
                        style: TextStyle(fontSize: 12, color: Colors.red[400]),
                      ),
                    ),
                  _buildNotificationToggleRow(
                    icon: Icons.vibration,
                    label: 'Vibrate',
                    value: prefs.vibrateEnabled,
                    isLoading: isLoading,
                    onChanged: notifier.setVibrate,
                  ),
                  const SizedBox(height: 8),
                  _buildNotificationToggleRow(
                    icon: Icons.volume_up,
                    label: 'Sound',
                    value: prefs.soundEnabled,
                    isLoading: isLoading,
                    onChanged: notifier.setSound,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required bool isLoading,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: isLoading ? null : onChanged,
          thumbColor: MaterialStateProperty.all(Colors.black),
          trackColor: MaterialStateProperty.resolveWith((states) {
            return states.contains(MaterialState.selected)
                ? const Color(0xFFFACC15)
                : Colors.grey.shade300;
          }),
        ),
      ],
    );
  }

  Widget _buildRegularMenuItem({
    required String label,
    required String svgPath,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SvgPicture.asset(
                svgPath,
                width: 22,
                height: 22,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: Colors.black,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }

  void _handleHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text(
          'For assistance, please contact your system administrator or check the user guide.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context, authService) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await authService.signOut();
            
            // Reset navigation stack and go to login/auth screen
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login', // or your auth screen route
                (route) => false,
              );
            }
          },
          child: const Text(
            'Logout',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );
}
}