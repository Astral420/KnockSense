import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/provider/admin_permissions_provider.dart';
import 'package:knocksense/provider/nfc_provider.dart';
import 'package:knocksense/provider/teacher_provider.dart';
import 'package:knocksense/screens/admin/admin_faculty_screen.dart';
import 'package:knocksense/screens/admin/admin_rfid_screen.dart';
import 'package:knocksense/services/auth_service.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminDashboard extends ConsumerWidget {
  final void Function(int) onJumpToTab;

  
  const AdminDashboard({
    super.key,
    required this.onJumpToTab,
  });

  // Design system colors from new UI
  static const Color kBrand = Color(0xFFFFD54F);
  static const Color kBg = Color(0xFFF4F5F7);
  static const Color kText = Color(0xFF141414);
  static const Color kSurface = Color(0xFFFFFFFF);
  static const Color kMuted = Color(0xFF888888);
  static const Color kGreen = Color(0xFF16A34A);
  static const Color kRed = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final authService = ref.read(authServiceProvider);
    final rfidTags = ref.watch(rfidTagsStreamProvider);
    final teachers = ref.watch(teachersStreamProvider);
    final adminPermissions = ref.watch(adminPermissionsProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const AdminPermissions(),
        );

    return user.when(
      data: (userData) {
        if (userData == null) {
          return const Scaffold(
            backgroundColor: kBg,
            body: Center(child: Text('User data not found.')),
          );
        }
        return Scaffold(
          backgroundColor: kBg,
          appBar: _buildAppBar(context, userData, authService),
          body: _buildBody(
            context,
            ref,
            userData,
            rfidTags,
            teachers,
            adminPermissions,
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: kBg,
        body: LoadingWidget(message: 'Loading dashboard...'),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: kBg,
        body: Center(child: Text('Error: $err')),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, UserModel userData, AuthService authService) {
    return AppBar(
      backgroundColor: kSurface,
      elevation: 0.5,
      title: Row(
        children: [
          Text(
            'KnockSense',
            style: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: kText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    UserModel userData,
    AsyncValue rfidTags,
    AsyncValue teachers,
    AdminPermissions permissions,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Quick Actions
            _buildQuickActions(context, ref, permissions),
            const SizedBox(height: 16),

            // Faculty Snapshot
            _buildFacultySnapshot(teachers),
            const SizedBox(height: 16),

            // Recent RFID Tags
            _buildRecentRfidTags(context, rfidTags),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    AdminPermissions permissions,
  ) {
    final canManageFaculty = permissions.removeTeacherAccounts;
    final facultyOnTap = canManageFaculty
        ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminFacultyScreen(),
              ),
            )
        : () => _showPermissionDeniedSnack(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.roboto(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kText,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                title: 'Faculty Accounts',
                subtitle: 'Manage Faculty Memebers',
                svgPath: 'assets/icons/faculty.svg',
                onTap: facultyOnTap,
                enabled: canManageFaculty,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                title: 'Manage RFID',
                subtitle: 'Register, assign, deactivate',
                svgPath: 'assets/icons/rfid.svg',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminRfidScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required String svgPath,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return AspectRatio(
      aspectRatio: 178 / 177,
      child: Material(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.5,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: kBrand,
                    child: SvgPicture.asset(
                      svgPath,
                      width: 24,
                      height: 24,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: kText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.roboto(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: kMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPermissionDeniedSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You do not have permission to manage faculty accounts. Contact a super admin.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildFacultySnapshot(AsyncValue teachers) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Faculty Snapshot',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEFA1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Overview',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xCC111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          teachers.when(
            data: (teacherList) {
              final totalCount = teacherList.length;
              final activeCount = teacherList.where((t) => t.activeStatus == 'online').length;
              final inactiveCount = totalCount - activeCount;

              return Row(
                children: [
                  Expanded(
                    child: _buildCountColumn(
                      value: totalCount.toString(),
                      label: 'Total',
                      color: kMuted,
                    ),
                  ),
                  Expanded(
                    child: _buildCountColumn(
                      value: activeCount.toString(),
                      label: 'Active',
                      color: kGreen,
                    ),
                  ),
                  Expanded(
                    child: _buildCountColumn(
                      value: inactiveCount.toString(),
                      label: 'Inactive',
                      color: kRed,
                    ),
                  ),
                ],
              );
            },
            loading: () => Row(
              children: const [
                Expanded(child: _CountColumnSkeleton()),
                Expanded(child: _CountColumnSkeleton()),
                Expanded(child: _CountColumnSkeleton()),
              ],
            ),
            error: (err, stack) => Text('Error loading stats'),
          ),
        ],
      ),
    );
  }

  Widget _buildCountColumn({
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.roboto(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentRfidTags(BuildContext context, AsyncValue rfidTags) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent RFID Tags',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kText,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminRfidScreen(),
                  ),
                ),
                child: SvgPicture.asset(
                  'assets/icons/material.svg',
                  width: 24,
                  height: 24,
                  semanticsLabel: 'View All',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          rfidTags.when(
            data: (tags) {
              if (tags.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No RFID tags registered yet',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: kMuted,
                    ),
                  ),
                );
              }
              
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '• System initialized. ${tags.length} RFID tags in Firebase RTDB.',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: kMuted,
                  ),
                ),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (err, stack) => Text(
              'Error loading RFID data',
              style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: kRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountColumnSkeleton extends StatelessWidget {
  const _CountColumnSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 30,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}