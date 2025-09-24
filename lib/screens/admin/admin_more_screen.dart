import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/screens/admin/admin_notifications_screen.dart';
import 'package:knocksense/screens/admin/admin_activity_logs_screen.dart';
import 'package:google_fonts/google_fonts.dart';

// Settings state providers
final darkModeProvider = StateProvider<bool>((ref) => false);
final notificationsEnabledProvider = StateProvider<bool>((ref) => true);
final expandSettingsProvider = StateProvider<bool>((ref) => false);
final searchQueryProvider = StateProvider<String>((ref) => '');

class AdminMoreScreen extends ConsumerWidget {
  const AdminMoreScreen({Key? key}) : super(key: key);

  // Design system colors
  static const Color kBg = Color(0xFFF7F8FB);
  static const Color kSurface = Color(0xFFFFFFFF);
  static const Color kText = Color(0xFF111827);
  static const Color kMuted = Color(0xFF888888);
  static const Color kYellow = Color(0xFFFACC15);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);
    final authService = ref.read(authServiceProvider);

    final menuItems = _getMenuItems(context, ref, authService);
    final filteredItems = menuItems
        .where((item) => item.label.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar(context),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Search Bar
              _buildSearchBar(ref, searchQuery),
              const SizedBox(height: 12),

              // Menu Items
              ...filteredItems.map((item) => _buildMenuItem(context, ref, item)),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: kSurface,
      elevation: 0.5,
      title: Text(
        'More',
        style: GoogleFonts.roboto(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: kText,
        ),
      ),
    );
  }

  Widget _buildSearchBar(WidgetRef ref, String currentQuery) {
    return Container(
      height: 43,
      decoration: BoxDecoration(
        color: const Color(0xFFECEDF2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x03000000)),
      ),
      child: TextField(
        onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
        style: GoogleFonts.roboto(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: kText,
        ),
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: GoogleFonts.roboto(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF565E6C),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(16, 9, 16, 8),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: SvgPicture.asset(
              'assets/icons/search.svg',
              width: 20,
              height: 20,
              semanticsLabel: 'Search',
            ),
          ),
        ),
      ),
    );
  }

  List<MenuItem> _getMenuItems(BuildContext context, WidgetRef ref, dynamic authService) {
    return [
      MenuItem(
        label: "Notifications",
        svgPath: 'assets/icons/bell.svg',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminNotificationsScreen()),
        ),
      ),
      MenuItem(
        label: "Settings",
        svgPath: 'assets/icons/gear.svg',
        isExpandable: true,
      ),
      MenuItem(
        label: "Activity Logs",
        svgPath: 'assets/icons/activity.svg',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminActivityLogsScreen()),
        ),
      ),
      MenuItem(
        label: "Help",
        svgPath: 'assets/icons/help.svg',
        onTap: () => _showHelpDialog(context),
      ),
      MenuItem(
        label: "Logout",
        svgPath: 'assets/icons/logout.svg',
        onTap: () => _showLogoutDialog(context, authService),
      ),
    ];
  }

  Widget _buildMenuItem(BuildContext context, WidgetRef ref, MenuItem item) {
    if (item.isExpandable && item.label == 'Settings') {
      return _buildSettingsCard(context, ref);
    }

    return _buildRegularMenuItem(item);
  }

  Widget _buildRegularMenuItem(MenuItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SvgPicture.asset(
                item.svgPath,
                width: 22,
                height: 22,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: kText,
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

  Widget _buildSettingsCard(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(expandSettingsProvider);
    final darkMode = ref.watch(darkModeProvider);
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header row
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => ref.read(expandSettingsProvider.notifier).state = !expanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/gear.svg',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Settings',
                      style: GoogleFonts.roboto(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: kText,
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

          // Expanded content
          if (expanded) const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          if (expanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  _buildSettingsRow(
                    svgPath: 'assets/icons/moon.svg',
                    label: 'Dark Mode',
                    value: darkMode,
                    onChanged: (value) => ref.read(darkModeProvider.notifier).state = value,
                  ),
                  const SizedBox(height: 8),
                  _buildSettingsRow(
                    svgPath: 'assets/icons/notif.svg',
                    label: 'Notifications',
                    value: notificationsEnabled,
                    onChanged: (value) => ref.read(notificationsEnabledProvider.notifier).state = value,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow({
    required String svgPath,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
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
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: kText,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          thumbColor: MaterialStateProperty.all(Colors.black),
          trackColor: MaterialStateProperty.resolveWith(
            (states) => states.contains(MaterialState.selected)
                ? kYellow
                : Colors.grey.shade300,
          ),
        ),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Help & Support',
            style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KnockSense Admin Dashboard',
                style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Version: 1.0.0',
                style: GoogleFonts.roboto(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Text(
                'For technical support or questions, please contact your system administrator.',
                style: GoogleFonts.roboto(),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context, dynamic authService) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Logout',
            style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: GoogleFonts.roboto(),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Logout'),
              onPressed: () async {
                Navigator.of(context).pop();
                await authService.signOut();
              },
            ),
          ],
        );
      },
    );
  }
}

class MenuItem {
  final String label;
  final String svgPath;
  final VoidCallback? onTap;
  final bool isExpandable;

  MenuItem({
    required this.label,
    required this.svgPath,
    this.onTap,
    this.isExpandable = false,
  });
}