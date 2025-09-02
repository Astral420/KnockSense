import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';
import 'package:knocksense/widgets/common/useravatar_widget.dart';

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await authService.signOut();
            },
          ),
        ],
      ),
      body: user.when(
        data: (userData) {
          if (userData == null) {
            return const Center(child: Text('User data not found.'));
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const UserAvatar(radius: 96),
                const SizedBox(height: 20),
                Text(
                  'Welcome, ${userData.displayName}!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text('Role: ${userData.role.name}'),
                if (userData.studentNumber != null)
                  Text('Student #: ${userData.studentNumber}'),
                Text('Email: ${userData.email}'),
              ],
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
