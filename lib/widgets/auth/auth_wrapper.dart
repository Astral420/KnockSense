import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/screens/auth/login_screen.dart';
import 'package:knocksense/screens/dashbaord/admin_dashboard.dart';
import 'package:knocksense/screens/dashbaord/student_dashboard.dart';
import 'package:knocksense/screens/dashbaord/teacher_dashboard.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }

        // Get current user data to determine role
        final currentUser = ref.watch(currentUserProvider);

        return currentUser.when(
          data: (userData) {
            if (userData == null) {
              return const Center(child: CircularProgressIndicator());
            }

            switch (userData.role) {
              case UserRole.admin:
                return const AdminDashboard();
              case UserRole.teacher:
                return const TeacherDashboard();
              case UserRole.student:
                return const StudentDashboard();
            }
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const LoginScreen(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const LoginScreen(),
    );
  }
}
