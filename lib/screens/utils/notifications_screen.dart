import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:knocksense/models/appointment_model.dart';
import 'package:knocksense/models/notification_model.dart';
import 'package:knocksense/models/user_models.dart';
// import 'package:knocksense/provider/appointment_provider.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/provider/notification_provider.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';
import 'package:knocksense/widgets/teacher_dash/teacher_response_widget.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _showOnlyUnread = false;

  void _showClearAllConfirmation(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
          'Are you sure you want to clear all notifications? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final notificationService = ref.read(userNotificationServiceProvider);
              final success = await notificationService.clearAllNotifications(user.uid);
              
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications cleared'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showMarkAllAsReadConfirmation(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark All as Read'),
        content: const Text(
          'Mark all notifications as read?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final notificationService = ref.read(userNotificationServiceProvider);
              final success = await notificationService.markAllAsRead(user.uid);
              
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Mark All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final notificationsAsync = ref.watch(userNotificationsProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFFDF6E3),
      body: SafeArea(
        child: currentUserAsync.when(
          data: (user) {
            if (user == null) {
              return const Center(child: Text('User not found'));
            }

            return notificationsAsync.when(
              data: (notifications) {
                // Filter based on toggle
                final displayedNotifications = _showOnlyUnread
                    ? notifications.where((n) => !n.isRead).toList()
                    : notifications;

                return Column(
                  children: [
                    // Header
                    _buildHeader(context, user, displayedNotifications.isNotEmpty),

                    // Filter Toggle
                    _buildFilterToggle(),

                    // Notifications List
                    Expanded(
                      child: displayedNotifications.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: displayedNotifications.length,
                              itemBuilder: (context, index) {
                                final notification = displayedNotifications[index];
                                return _buildNotificationCard(
                                  context: context,
                                  notification: notification,
                                  user: user,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
              loading: () => const LoadingWidget(),
              error: (err, stack) => Center(
                child: Text('Error loading notifications: $err'),
              ),
            );
          },
          loading: () => const LoadingWidget(),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserModel user, bool hasNotifications) {
    return Container(
      color: const Color(0xFFFDF6E3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.chevron_left,
              size: 32,
              color: Color(0xFF6B4423),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B4423),
                ),
              ),
            ),
          ),
          if (hasNotifications)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'mark_all_read') {
                  _showMarkAllAsReadConfirmation(context, user);
                } else if (value == 'clear_all') {
                  _showClearAllConfirmation(context, user);
                }
              },
              icon: const Icon(
                Icons.more_horiz,
                size: 28,
                color: Color(0xFF6B4423),
              ),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'mark_all_read',
                  child: Row(
                    children: [
                      Icon(Icons.done_all, size: 20),
                      SizedBox(width: 12),
                      Text('Mark All as Read'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Clear All'),
                    ],
                  ),
                ),
              ],
            )
          else
            const SizedBox(width: 32), // Spacer to keep title centered
        ],
      ),
    );
  }

  Widget _buildFilterToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('All'),
                  icon: Icon(Icons.notifications, size: 18),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Unread'),
                  icon: Icon(Icons.notification_important, size: 18),
                ),
              ],
              selected: {_showOnlyUnread},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() {
                  _showOnlyUnread = newSelection.first;
                });
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Color(0xFFF4C21A);
                    }
                    return Colors.white;
                  },
                ),
                foregroundColor: MaterialStateProperty.resolveWith<Color>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.selected)) {
                      return Colors.black87;
                    }
                    return Colors.grey;
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showOnlyUnread
                ? Icons.notifications_none
                : Icons.notifications_off_outlined,
            size: 64,
            color: Colors.brown[300],
          ),
          const SizedBox(height: 16),
          Text(
            _showOnlyUnread
                ? 'No unread notifications'
                : 'No notifications',
            style: TextStyle(
              fontSize: 18,
              color: Colors.brown[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showOnlyUnread
                ? 'You\'re all caught up!'
                : 'Notifications will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.brown[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard({
    required BuildContext context,
    required NotificationModel notification,
    required UserModel user,
  }) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        final notificationService = ref.read(userNotificationServiceProvider);
        final success = await notificationService.deleteNotification(
          user.uid,
          notification.id,
        );
        return success;
      },
      child: GestureDetector(
        onTap: () => _handleNotificationTap(context, notification, user),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.white
                : const Color(0xFFFFE69C).withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? Colors.grey[200]!
                  : const Color(0xFFF4C21A).withOpacity(0.5),
              width: notification.isRead ? 1 : 2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon based on notification type
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getNotificationIconColor(notification.type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationIconColor(notification.type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Notification content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF4C21A),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.brown[700],
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getTimeAgo(notification.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        if (_getNotificationTypeBadge(notification.type) != null)
                          _getNotificationTypeBadge(notification.type)!,
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    NotificationModel notification,
    UserModel user,
  ) async {
    // Mark as read if not already
    if (!notification.isRead) {
      final notificationService = ref.read(userNotificationServiceProvider);
      await notificationService.markAsRead(user.uid, notification.id);
    }

    // Handle different notification types
    switch (notification.type) {
      case NotificationType.appointment:
      case NotificationType.immediateAppointment:
      case NotificationType.appointmentScheduled:
      case NotificationType.appointmentDue:
        await _handleAppointmentNotification(context, notification, user);
        break;

      case NotificationType.appointmentAccepted:
      case NotificationType.appointmentRejected:
      case NotificationType.appointmentCancelled:
        // For students, show info dialog about their appointment status
        if (user.role == UserRole.student) {
          _showAppointmentStatusDialog(context, notification);
        }
        break;

      case NotificationType.teacherStatusChange:
        // Show info about teacher status change
        _showInfoDialog(context, notification);
        break;

      default:
        // General notification - just show info
        _showInfoDialog(context, notification);
    }
  }

  Future<void> _handleAppointmentNotification(
    BuildContext context,
    NotificationModel notification,
    UserModel user,
  ) async {
    // Extract appointment data from notification
    final appointmentId = notification.data?['appointmentId'] as String?;
    final studentNumber = notification.data?['studentNumber'] as String?;

    if (appointmentId == null) {
      _showInfoDialog(context, notification);
      return;
    }

    // For teachers, show the teacher response widget
    if (user.role == UserRole.teacher) {
      // Fetch the appointment details
      try {
        final database = ref.read(firebaseDatabaseProvider);
        
        // Get appointment from student's appointments
        if (studentNumber != null) {
          final appointmentSnapshot = await database
              .ref('appointments/$studentNumber/$appointmentId')
              .get();

          if (appointmentSnapshot.exists && appointmentSnapshot.value != null) {
            final appointmentData = Map<String, dynamic>.from(
              appointmentSnapshot.value as Map,
            );
            final appointment = AppointmentModel.fromJson(
              appointmentId,
              appointmentData,
            );

            // Check if appointment is still actionable (pending or accepted but not completed)
            if (appointment.status == AppointmentStatus.completed ||
                appointment.status == AppointmentStatus.denied ||
                appointment.status == AppointmentStatus.cancelled) {
              // Appointment is no longer actionable
              _showInfoDialog(context, NotificationModel(
                id: notification.id,
                userId: notification.userId,
                title: 'Appointment Already Handled',
                body: 'This appointment has already been ${appointment.status.name}.',
                type: notification.type,
                createdAt: notification.createdAt,
                isRead: notification.isRead,
              ));
              return;
            }

            // Show teacher response widget only for pending/accepted appointments
            if (mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => TeacherResponseWidget(
                  appointment: appointment,
                  currentUser: user,
                ),
              );
            }
          } else {
            _showErrorDialog(context, 'Appointment not found or has been removed.');
          }
        }
      } catch (e) {
        _showErrorDialog(context, 'Error loading appointment: $e');
      }
    } else {
      // For students, just show the notification details
      _showInfoDialog(context, notification);
    }
  }

  void _showInfoDialog(BuildContext context, NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: Text(notification.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAppointmentStatusDialog(
    BuildContext context,
    NotificationModel notification,
  ) {
    final teacherResponse = notification.data?['teacherResponse'] as String?;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body),
            if (teacherResponse != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Teacher\'s Response:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(teacherResponse),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.appointment:
      case NotificationType.immediateAppointment:
      case NotificationType.appointmentScheduled:
        return Icons.calendar_today;
      case NotificationType.appointmentAccepted:
        return Icons.check_circle;
      case NotificationType.appointmentRejected:
      case NotificationType.appointmentCancelled:
        return Icons.cancel;
      case NotificationType.appointmentDue:
        return Icons.alarm;
      case NotificationType.teacherStatusChange:
        return Icons.person;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationIconColor(NotificationType type) {
    switch (type) {
      case NotificationType.appointmentAccepted:
        return Colors.green;
      case NotificationType.appointmentRejected:
      case NotificationType.appointmentCancelled:
        return Colors.red;
      case NotificationType.appointmentDue:
        return Colors.orange;
      case NotificationType.teacherStatusChange:
        return Colors.blue;
      default:
        return Colors.brown;
    }
  }

  Widget? _getNotificationTypeBadge(NotificationType type) {
    String? badgeText;
    Color? badgeColor;

    switch (type) {
      case NotificationType.appointmentDue:
        badgeText = 'Urgent';
        badgeColor = Colors.orange;
        break;
      case NotificationType.immediateAppointment:
        badgeText = 'Now';
        badgeColor = Colors.green;
        break;
      case NotificationType.appointmentScheduled:
        badgeText = 'Scheduled';
        badgeColor = Colors.purple;
        break;
      default:
        return null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        badgeText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'min' : 'mins'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }
}
