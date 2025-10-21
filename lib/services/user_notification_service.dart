import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:knocksense/models/notification_model.dart';

class UserNotificationService {
  final FirebaseDatabase _database;

  UserNotificationService({required FirebaseDatabase database})
      : _database = database;

  // Get notifications stream for a user
  Stream<List<NotificationModel>> getUserNotificationsStream(String userId) {
    return _database
        .ref('user_notifications/$userId')
        .orderByChild('createdAt')
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <NotificationModel>[];
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final notifications = <NotificationModel>[];

      for (var entry in data.entries) {
        try {
          final notificationData = Map<String, dynamic>.from(entry.value as Map);
          notifications.add(
            NotificationModel.fromJson(entry.key, notificationData),
          );
        } catch (e) {
          debugPrint('Error parsing notification ${entry.key}: $e');
        }
      }

      // Sort by createdAt descending (newest first)
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return notifications;
    });
  }

  // Mark notification as read
  Future<bool> markAsRead(String userId, String notificationId) async {
    try {
      await _database
          .ref('user_notifications/$userId/$notificationId/isRead')
          .set(true);
      debugPrint('✅ Marked notification $notificationId as read');
      return true;
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      return false;
    }
  }

  // Mark all notifications as read
  Future<bool> markAllAsRead(String userId) async {
    try {
      final snapshot = await _database.ref('user_notifications/$userId').get();

      if (!snapshot.exists || snapshot.value == null) {
        return true;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final updates = <String, dynamic>{};

      for (var notificationId in data.keys) {
        updates['user_notifications/$userId/$notificationId/isRead'] = true;
      }

      if (updates.isNotEmpty) {
        await _database.ref().update(updates);
        debugPrint('✅ Marked all ${updates.length} notifications as read');
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
      return false;
    }
  }

  // Delete a notification
  Future<bool> deleteNotification(String userId, String notificationId) async {
    try {
      await _database
          .ref('user_notifications/$userId/$notificationId')
          .remove();
      debugPrint('✅ Deleted notification $notificationId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
      return false;
    }
  }

  // Clear all notifications
  Future<bool> clearAllNotifications(String userId) async {
    try {
      await _database.ref('user_notifications/$userId').remove();
      debugPrint('✅ Cleared all notifications for user $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Error clearing all notifications: $e');
      return false;
    }
  }

  // Create a notification (used by backend/cloud functions)
  Future<bool> createNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notificationRef = _database.ref('user_notifications/$userId').push();

      final notification = NotificationModel(
        id: notificationRef.key!,
        userId: userId,
        title: title,
        body: body,
        type: type,
        createdAt: DateTime.now(),
        isRead: false,
        data: data,
      );

      await notificationRef.set(notification.toJson());
      debugPrint('✅ Created notification: $title');
      return true;
    } catch (e) {
      debugPrint('❌ Error creating notification: $e');
      return false;
    }
  }

  // Get unread count
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _database
          .ref('user_notifications/$userId')
          .orderByChild('isRead')
          .equalTo(false)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return 0;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      return data.length;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  // Stream for unread count
  Stream<int> getUnreadCountStream(String userId) {
    return _database
        .ref('user_notifications/$userId')
        .orderByChild('isRead')
        .equalTo(false)
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return 0;
      }
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return data.length;
    });
  }
}
