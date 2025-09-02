import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/screens/auth/login_screen.dart';
import 'package:knocksense/screens/dashbaord/admin_dashboard.dart';
import 'package:knocksense/screens/dashbaord/student_dashboard.dart';
import 'package:knocksense/screens/dashbaord/teacher_dashboard.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          // No authenticated user, show login screen
          return const LoginScreen();
        }

        // User is authenticated, get their details
        final userDetails = ref.watch(currentUserProvider);

        return userDetails.when(
          data: (userModel) {
            // If userModel is null, it means either:
            // 1. The database record doesn't exist (shouldn't happen after proper sign-in)
            // 2. There's a temporary loading state
            // In either case, we should sign out and return to login
            if (userModel == null) {
              // Sign out the user to force them to re-authenticate
              // This ensures the database record gets created properly
              Future.microtask(() async {
                final authService = ref.read(authServiceProvider);
                await authService.signOut();
              });
              
              return const Scaffold(
                body: LoadingWidget(message: 'Initializing...'),
              );
            }

            // Once we have the data, navigate to the correct dashboard
            switch (userModel.role) {
              case UserRole.admin:
                return const AdminDashboard();
              case UserRole.teacher:
                return const TeacherDashboard();
              case UserRole.student:
                return const StudentDashboard();
            }
          },
          loading: () => const Scaffold(
            body: LoadingWidget(message: 'Loading user profile...'),
          ),
          error: (err, stack) {
            // On error, sign out and return to login
            Future.microtask(() async {
              final authService = ref.read(authServiceProvider);
              await authService.signOut();
            });
            
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error loading user data'),
                    SizedBox(height: 16),
                    Text('Please try signing in again'),
                  ],
                ),
              ),
            );
          },
        );
      },
      // While checking the initial Firebase auth state, show a spinner
      loading: () => const Scaffold(body: LoadingWidget(message: 'Connecting...')),
      error: (err, stack) => const Scaffold(
        body: Center(child: Text('Authentication failed. Please restart the app.')),
      ),
    );
  }
}