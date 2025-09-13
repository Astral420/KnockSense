import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/provider/teacher_provider.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';
import 'package:knocksense/widgets/student_dash/teacher_detail_modal.dart';

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final authService = ref.read(authServiceProvider);
    final teachers = ref.watch(teachersStreamProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: user.when(
          data: (userData) {
            if (userData == null) {
              return const Center(child: Text('User data not found.'));
            }
            return CustomScrollView(
              slivers: [
                // App Bar
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'KnockSense',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                userData.role.name.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined),
                              onPressed: () {},
                            ),
                          
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search Faculty Members',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),

                // Faculty Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Faculty',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Teachers Grid (Horizontal)
                teachers.when(
                  data: (teachersList) {
                    if (teachersList.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Container(
                          height: 140,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Center(
                            child: Text(
                              'No faculty members found',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverToBoxAdapter(
                      child: SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: teachersList.length,
                          itemBuilder: (context, index) {
                            final teacher = teachersList[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: GestureDetector(
                                onTap: () => context.showTeacherDetail(teacher),
                                child: Column(
                                  children: [
                                    Stack(
                                      children: [
                                        // Updated to use CachedNetworkImage
                                        teacher.photoUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl: teacher.photoUrl!,
                                                imageBuilder: (context, imageProvider) => CircleAvatar(
                                                  radius: 40,
                                                  backgroundImage: imageProvider,
                                                ),
                                                placeholder: (context, url) => CircleAvatar(
                                                  radius: 40,
                                                  backgroundColor: Colors.amber,
                                                  child: const SizedBox(
                                                    width: 30,
                                                    height: 30,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  ),
                                                ),
                                                errorWidget: (context, url, error) => CircleAvatar(
                                                  radius: 40,
                                                  backgroundColor: Colors.amber,
                                                  child: Text(
                                                    teacher.initials,
                                                    style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : CircleAvatar(
                                                radius: 40,
                                                backgroundColor: Colors.amber,
                                                child: Text(
                                                  teacher.initials,
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(teacher.activeStatus),
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
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        _getDisplayName(teacher.displayName),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, stack) => SliverToBoxAdapter(
                    child: Center(child: Text('Error loading teachers: $err')),
                  ),
                ),

                // Recently Knocked Section (Placeholder for now)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recently Knocked',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 0,
                          color: Colors.grey[100],
                          child: const ListTile(
                            leading: Icon(Icons.schedule, color: Colors.grey),
                            title: Text('No recent appointments'),
                            subtitle: Text('Your recent appointments will appear here'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Availability Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Availability',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Teachers List with Status (Vertical)
                teachers.when(
                  data: (teachersList) {
                    if (teachersList.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Card(
                            elevation: 0,
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No faculty members available',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final teacher = teachersList[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Card(
                              elevation: 0,
                              color: Colors.white,
                              child: ListTile(
                                leading: teacher.photoUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: teacher.photoUrl!,
                                        imageBuilder: (context, imageProvider) => CircleAvatar(
                                          radius: 24,
                                          backgroundImage: imageProvider,
                                        ),
                                        placeholder: (context, url) => CircleAvatar(
                                          radius: 24,
                                          backgroundColor: Colors.amber,
                                          child: const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => CircleAvatar(
                                          radius: 24,
                                          backgroundColor: Colors.amber,
                                          child: Text(
                                            teacher.initials,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      )
                                    : CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Colors.amber,
                                        child: Text(
                                          teacher.initials,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                title: Text(
                                  teacher.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  teacher.teacherID,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(teacher.activeStatus)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatStatus(teacher.activeStatus),
                                    style: TextStyle(
                                      color: _getStatusColor(teacher.activeStatus),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                onTap: () => context.showTeacherDetail(teacher),
                              ),
                            ),
                          );
                        },
                        childCount: teachersList.length,
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, stack) => SliverToBoxAdapter(
                    child: Center(child: Text('Error: $err')),
                  ),
                ),

                // Add extra padding at bottom to avoid content being hidden behind bottom nav
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            );
          },
          loading: () => const LoadingWidget(),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
      // Remove the bottomNavigationBar from here since it's now handled by MainNavigation
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'busy':
        return Colors.orange;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  String _getDisplayName(String fullName) {
    // Extract last name for display in the horizontal list
    final parts = fullName.split(' ');
    if (parts.length > 1) {
      return parts.last; // Return last name
    }
    return fullName; // Return full name if only one word
  }
}