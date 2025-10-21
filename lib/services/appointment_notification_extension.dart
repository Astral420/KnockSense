import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:knocksense/models/appointment_model.dart';
import 'package:knocksense/models/notification_model.dart';

/// Extension methods for AppointmentService to create user notifications
/// These notifications are stored in Firebase and displayed in the notifications screen
extension AppointmentNotificationExtension on FirebaseDatabase {
  // Helper method to create a user notification
  Future<void> createUserNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notificationRef = ref('user_notifications/$userId').push();

      final notification = {
        'userId': userId,
        'title': title,
        'body': body,
        'type': type.name,
        'createdAt': ServerValue.timestamp,
        'isRead': false,
        'data': data,
      };

      await notificationRef.set(notification);
      debugPrint('✅ User notification created: $title for user $userId');
    } catch (e) {
      debugPrint('❌ Error creating user notification: $e');
    }
  }

  // Notification for immediate appointment (teacher receives)
  Future<void> notifyTeacherOfImmediateAppointment({
    required String teacherUid,
    required String studentName,
    required String appointmentId,
    required String studentNumber,
  }) async {
    final cleanStudentName = studentName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    
    await createUserNotification(
      userId: teacherUid,
      title: '🔔 New Appointment Request',
      body: '$cleanStudentName is requesting an appointment right now.',
      type: NotificationType.immediateAppointment,
      data: {
        'appointmentId': appointmentId,
        'studentNumber': studentNumber,
        'studentName': cleanStudentName,
      },
    );
  }

  // Notification for scheduled appointment (teacher receives)
  Future<void> notifyTeacherOfScheduledAppointment({
    required String teacherUid,
    required String studentName,
    required String appointmentId,
    required String studentNumber,
    required DateTime scheduledTime,
  }) async {
    final cleanStudentName = studentName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    final timeString = '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';
    
    await createUserNotification(
      userId: teacherUid,
      title: '📅 Scheduled Appointment',
      body: '$cleanStudentName scheduled an appointment for $timeString.',
      type: NotificationType.appointmentScheduled,
      data: {
        'appointmentId': appointmentId,
        'studentNumber': studentNumber,
        'studentName': cleanStudentName,
        'scheduledTime': scheduledTime.millisecondsSinceEpoch,
      },
    );
  }

  // Notification when appointment is due (teacher receives)
  Future<void> notifyTeacherAppointmentDue({
    required String teacherUid,
    required String studentName,
    required String appointmentId,
    required String studentNumber,
  }) async {
    final cleanStudentName = studentName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    
    await createUserNotification(
      userId: teacherUid,
      title: '⏰ Appointment Ready',
      body: '$cleanStudentName\'s appointment time has arrived. Please respond within 2 minutes.',
      type: NotificationType.appointmentDue,
      data: {
        'appointmentId': appointmentId,
        'studentNumber': studentNumber,
        'studentName': cleanStudentName,
        'urgency': 'high',
      },
    );
  }

  // Notification when teacher accepts appointment (student receives)
  Future<void> notifyStudentAppointmentAccepted({
    required String studentUid,
    required String teacherName,
    required TeacherAction action,
    String? teacherResponse,
  }) async {
    final cleanTeacherName = teacherName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    String title;
    String body;

    switch (action) {
      case TeacherAction.meetNow:
        title = '✅ Meeting Ready';
        body = '$cleanTeacherName is ready to meet you now!';
        break;
      case TeacherAction.wait5Minutes:
        title = '⏳ Please Wait';
        body = '$cleanTeacherName asks you to wait 5 minutes before coming.';
        break;
      case TeacherAction.meetLater:
        title = '📅 Meeting Scheduled';
        body = '$cleanTeacherName has scheduled your appointment for later.';
        break;
      default:
        title = 'Appointment Update';
        body = '$cleanTeacherName has updated your appointment.';
    }

    // Only add teacher response for meetNow and wait5Minutes, not for meetLater
    if (teacherResponse != null && teacherResponse.isNotEmpty && 
        action != TeacherAction.meetLater) {
      body += '\n\nNote: $teacherResponse';
    }

    await createUserNotification(
      userId: studentUid,
      title: title,
      body: body,
      type: NotificationType.appointmentAccepted,
      data: {
        'teacherName': cleanTeacherName,
        'action': action.name,
        'teacherResponse': teacherResponse,
      },
    );
  }

  // Notification when teacher rejects appointment (student receives)
  Future<void> notifyStudentAppointmentRejected({
    required String studentUid,
    required String teacherName,
    String? teacherResponse,
  }) async {
    final cleanTeacherName = teacherName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    
    String body = '$cleanTeacherName declined your appointment request.';
    if (teacherResponse != null && teacherResponse.isNotEmpty) {
      body += '\n\nReason: $teacherResponse';
    }

    await createUserNotification(
      userId: studentUid,
      title: '❌ Appointment Declined',
      body: body,
      type: NotificationType.appointmentRejected,
      data: {
        'teacherName': cleanTeacherName,
        'teacherResponse': teacherResponse,
      },
    );
  }

  // Notification when appointment is cancelled (student receives)
  Future<void> notifyStudentAppointmentCancelled({
    required String studentUid,
    required String teacherName,
    required String reason,
  }) async {
    final cleanTeacherName = teacherName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    
    String body = '$cleanTeacherName has cancelled your appointment.';
    if (reason.isNotEmpty) {
      body += '\n\nReason: $reason';
    }

    await createUserNotification(
      userId: studentUid,
      title: '🚫 Meeting Cancelled',
      body: body,
      type: NotificationType.appointmentCancelled,
      data: {
        'teacherName': cleanTeacherName,
        'reason': reason,
      },
    );
  }

  // Notification when appointment is auto-rejected (student receives)
  Future<void> notifyStudentAppointmentAutoRejected({
    required String studentUid,
    required String teacherName,
    required String message,
  }) async {
    final cleanTeacherName = teacherName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    
    await createUserNotification(
      userId: studentUid,
      title: '⏰ Appointment Expired',
      body: '$cleanTeacherName did not respond to your scheduled appointment.\n\n$message',
      type: NotificationType.appointmentCancelled,
      data: {
        'teacherName': cleanTeacherName,
        'message': message,
        'autoRejected': true,
      },
    );
  }

  // Notification when teacher status changes (subscribed students receive)
  Future<void> notifyStudentOfTeacherStatusChange({
    required String studentUid,
    required String teacherName,
    required String teacherUid,
    required String newStatus,
  }) async {
    final cleanTeacherName = teacherName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    String statusEmoji;
    String statusText;
    
    switch (newStatus.toLowerCase()) {
      case 'online':
        statusEmoji = '✅';
        statusText = 'now online';
        break;
      case 'busy':
        statusEmoji = '🟡';
        statusText = 'now busy';
        break;
      case 'offline':
        statusEmoji = '⚫';
        statusText = 'now offline';
        break;
      default:
        statusEmoji = '🔔';
        statusText = 'updated their status';
    }
    
    await createUserNotification(
      userId: studentUid,
      title: '$statusEmoji $cleanTeacherName is $statusText',
      body: 'Tap to view details',
      type: NotificationType.teacherStatusChange,
      data: {
        'teacherUid': teacherUid,
        'teacherName': cleanTeacherName,
        'status': newStatus,
      },
    );
  }

  // Notification when teacher posts/updates a message (subscribed students receive)
  Future<void> notifyStudentOfTeacherMessage({
    required String studentUid,
    required String teacherName,
    required String teacherUid,
    required String message,
  }) async {
    final cleanTeacherName = teacherName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    final messageText = message.isEmpty ? 'Note cleared' : message;
    
    await createUserNotification(
      userId: studentUid,
      title: '📝 $cleanTeacherName posted an update',
      body: messageText,
      type: NotificationType.teacherStatusChange, // Using same type for teacher updates
      data: {
        'teacherUid': teacherUid,
        'teacherName': cleanTeacherName,
        'message': message,
      },
    );
  }
}
