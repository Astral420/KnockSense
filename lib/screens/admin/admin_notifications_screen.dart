import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminNotificationsScreen extends ConsumerWidget {
  const AdminNotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock notification data - replace with real data from your backend
    final notifications = [
      NotificationItem(
        title: "System",
        message: "Daily backup completed successfully",
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        type: NotificationType.system,
      ),
      NotificationItem(
        title: "Admin",
        message: "3 new RFID registrations pending approval",
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        type: NotificationType.admin,
      ),
      NotificationItem(
        title: "Security",
        message: "Failed login attempt blocked from unknown device",
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        type: NotificationType.security,
      ),
      NotificationItem(
        title: "Faculty",
        message: "Prof. Santos updated availability status",
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        type: NotificationType.faculty,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) => _buildNotificationCard(notifications[index]),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: notifications.length,
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: _buildNotificationIcon(notification.type),
        title: Text(
          notification.title,
          style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.message,
              style: GoogleFonts.roboto(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(notification.timestamp),
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          // Handle notification tap
        },
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationType type) {
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.system:
        icon = Icons.settings;
        color = Colors.blue;
        break;
      case NotificationType.admin:
        icon = Icons.admin_panel_settings;
        color = Colors.orange;
        break;
      case NotificationType.security:
        icon = Icons.security;
        color = Colors.red;
        break;
      case NotificationType.faculty:
        icon = Icons.people;
        color = Colors.green;
        break;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class NotificationItem {
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;

  NotificationItem({
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
  });
}

enum NotificationType {
  system,
  admin,
  security,
  faculty,
}