import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/notification_model.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/services/user_notification_service.dart';

// Provider for UserNotificationService
final userNotificationServiceProvider = Provider<UserNotificationService>((ref) {
  final database = ref.read(firebaseDatabaseProvider);
  return UserNotificationService(database: database);
});

// Stream provider for user notifications
final userNotificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final currentUser = ref.watch(currentUserProvider).asData?.value;
  
  if (currentUser == null) {
    return Stream.value([]);
  }

  final notificationService = ref.read(userNotificationServiceProvider);
  return notificationService.getUserNotificationsStream(currentUser.uid);
});

// Stream provider for unread count
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final currentUser = ref.watch(currentUserProvider).asData?.value;
  
  if (currentUser == null) {
    return Stream.value(0);
  }

  final notificationService = ref.read(userNotificationServiceProvider);
  return notificationService.getUnreadCountStream(currentUser.uid);
});

// Provider for unread notifications only
final unreadNotificationsProvider = Provider<List<NotificationModel>>((ref) {
  final notifications = ref.watch(userNotificationsProvider).asData?.value ?? [];
  return notifications.where((n) => !n.isRead).toList();
});

// Provider for read notifications only
final readNotificationsProvider = Provider<List<NotificationModel>>((ref) {
  final notifications = ref.watch(userNotificationsProvider).asData?.value ?? [];
  return notifications.where((n) => n.isRead).toList();
});
