import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/rfid_model.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/provider/nfc_provider.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';
import 'package:knocksense/screens/admin/admin_management_page.dart'; // Import your RFID management page

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({Key? key}) : super(key: key);

String _getStatusName(Status status) {
    switch (status) {
      case Status.active:
        return 'active';
      case Status.inactive:
        return 'inactive';
      default:
        return 'inactive';
    }
  }



  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final authService = ref.read(authServiceProvider);
    final rfidTags = ref.watch(rfidTagsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await authService.signOut();
              // The AuthWrapper will automatically handle navigation
            },
          ),
        ],
      ),
      body: user.when(
        data: (userData) {
          if (userData == null) {
            return const Center(child: Text('User data not found.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                _buildWelcomeSection(context, userData),
                const SizedBox(height: 24),
                
                // Dashboard Overview Cards
                _buildOverviewCards(context, rfidTags),
                const SizedBox(height: 24),
                
                // Quick Actions Section
                _buildQuickActions(context),
                const SizedBox(height: 24),
                
                // Recent RFID Tags Section
                _buildRecentRfidTags(context, rfidTags),
              ],
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, UserModel userData) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blueAccent,
              child: Icon(
                Icons.admin_panel_settings,
                size: 30,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${userData.displayName}!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Role: ${userData.role.name}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Email: ${userData.email}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards(BuildContext context, AsyncValue rfidTags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        rfidTags.when(
          data: (tags) {
            final activeTags = tags.where((tag) => _getStatusName(tag.status) == 'active').length;
            final inactiveTags = tags.where((tag) => _getStatusName(tag.status) == 'inactive').length;
            final assignedTags = tags.where((tag) => tag.assignedTo != null).length;
            
            return Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Total RFID Tags',
                    tags.length.toString(),
                    Icons.credit_card,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Active Tags',
                    activeTags.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            );
          },
          loading: () => Row(
            children: [
              Expanded(child: _buildLoadingCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildLoadingCard()),
            ],
          ),
          error: (err, stack) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading stats: $err'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 40,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: 80,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildActionCard(
              context,
              'Manage RFID',
              'Add, edit, or delete RFID tags',
              Icons.nfc,
              Colors.purple,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminRFIDManagementPage(),
                ),
              ),
            ),
            _buildActionCard(
              context,
              'User Management',
              'Manage system users',
              Icons.people,
              Colors.orange,
              () {
                // Navigate to user management page
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User Management - Coming Soon')),
                );
              },
            ),
            _buildActionCard(
              context,
              'System Settings',
              'Configure system preferences',
              Icons.settings,
              Colors.teal,
              () {
                // Navigate to settings page
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('System Settings - Coming Soon')),
                );
              },
            ),
            _buildActionCard(
              context,
              'Reports',
              'View system reports',
              Icons.analytics,
              Colors.indigo,
              () {
                // Navigate to reports page
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reports - Coming Soon')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle, 
      IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentRfidTags(BuildContext context, AsyncValue rfidTags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent RFID Tags',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminRFIDManagementPage(),
                ),
              ),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          child: rfidTags.when(
            data: (tags) {
              if (tags.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.credit_card_off, 
                             size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'No RFID tags registered',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminRFIDManagementPage(),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Add First Tag'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Show only the 5 most recent tags
              final recentTags = tags.take(5).toList();
              
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentTags.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final tag = recentTags[index];
                  final statusName = _getStatusName(tag.status);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusName == 'active'
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      child: Icon(
                        Icons.credit_card,
                        color: statusName == 'active'
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      tag.rfid_uid,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      tag.assignedTo ?? 'Unassigned',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: tag.status.name == 'active'
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag.status.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: tag.status.name == 'active'
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text('Error loading RFID tags: $err'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}