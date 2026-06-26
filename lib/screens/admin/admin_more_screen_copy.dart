import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:knocksense/provider/auth_provider.dart';

final adminMoreCopySearchQueryProvider = StateProvider<String>((ref) => '');
final adminMoreCopyExpandSettingsProvider = StateProvider<bool>((ref) => false);
final notificationVibratePreferenceProvider = StateProvider<bool>((ref) => true);
final notificationSoundPreferenceProvider = StateProvider<bool>((ref) => true);

class AdminMoreScreenCopy extends ConsumerWidget {
  const AdminMoreScreenCopy({super.key});

  static const Color kBg = Color(0xFFF7F8FB);
  static const Color kSurface = Color(0xFFFFFFFF);
  static const Color kText = Color(0xFF111827);
  static const Color kMuted = Color(0xFF888888);
  static const Color kYellow = Color(0xFFFACC15);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(adminMoreCopySearchQueryProvider);
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
              _buildSearchBar(ref, searchQuery),
              const SizedBox(height: 12),
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
        onChanged: (value) => ref.read(adminMoreCopySearchQueryProvider.notifier).state = value,
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

  List<AdminMoreCopyMenuItem> _getMenuItems(
    BuildContext context,
    WidgetRef ref,
    dynamic authService,
  ) {
    return [
      AdminMoreCopyMenuItem(
        label: 'Notification Settings',
        svgPath: 'assets/icons/gear.svg',
        isExpandable: true,
      ),
      AdminMoreCopyMenuItem(
        label: 'Logout',
        svgPath: 'assets/icons/logout.svg',
        onTap: () => _showLogoutDialog(context, authService),
      ),
    ];
  }

  Widget _buildMenuItem(BuildContext context, WidgetRef ref, AdminMoreCopyMenuItem item) {
    if (item.isExpandable) {
      return _buildNotificationSettingsCard(context, ref);
    }

    return _buildRegularMenuItem(item);
  }

  Widget _buildRegularMenuItem(AdminMoreCopyMenuItem item) {
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

  Widget _buildNotificationSettingsCard(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(adminMoreCopyExpandSettingsProvider);
    final vibrateEnabled = ref.watch(notificationVibratePreferenceProvider);
    final soundEnabled = ref.watch(notificationSoundPreferenceProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => ref.read(adminMoreCopyExpandSettingsProvider.notifier).state = !expanded,
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
                      'Notification Settings',
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
          if (expanded) const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          if (expanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  _buildNotificationToggleRow(
                    icon: Icons.vibration,
                    label: 'Vibrate',
                    value: vibrateEnabled,
                    onChanged: (value) =>
                        ref.read(notificationVibratePreferenceProvider.notifier).state = value,
                  ),
                  const SizedBox(height: 8),
                  _buildNotificationToggleRow(
                    icon: Icons.volume_up,
                    label: 'Sound',
                    value: soundEnabled,
                    onChanged: (value) =>
                        ref.read(notificationSoundPreferenceProvider.notifier).state = value,
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
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 22, color: kMuted),
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
            (states) => states.contains(MaterialState.selected) ? kYellow : Colors.grey.shade300,
          ),
        ),
      ],
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

class AdminMoreCopyMenuItem {
  final String label;
  final String svgPath;
  final VoidCallback? onTap;
  final bool isExpandable;

  AdminMoreCopyMenuItem({
    required this.label,
    required this.svgPath,
    this.onTap,
    this.isExpandable = false,
  });
}
