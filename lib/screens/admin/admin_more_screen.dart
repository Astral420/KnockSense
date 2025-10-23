import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/provider/admin_permissions_provider.dart';
import 'package:knocksense/screens/admin/admin_activity_logs_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminMoreScreen extends ConsumerWidget {
  const AdminMoreScreen({Key? key}) : super(key: key);

  // Design system colors
  static const Color kBg = Color(0xFFF7F8FB);
  static const Color kSurface = Color(0xFFFFFFFF);
  static const Color kText = Color(0xFF111827);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.read(authServiceProvider);
    final permissions = ref.watch(adminPermissionsProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const AdminPermissions(),
        );

    final menuItems = _getMenuItems(context, authService, permissions);

    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar(context),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              ...menuItems.map(_buildMenuItem),
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

  List<MenuItem> _getMenuItems(
    BuildContext context,
    dynamic authService,
    AdminPermissions permissions,
  ) {
    final items = <MenuItem>[];

    if (permissions.seeAttendanceLogs) {
      items.add(
        MenuItem(
          label: "Activity Logs",
          svgPath: 'assets/icons/activity.svg',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminActivityLogsScreen()),
          ),
        ),
      );
    }

    items.addAll([
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
    ]);

    return items;
  }

  Widget _buildMenuItem(MenuItem item) {
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