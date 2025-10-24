import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:knocksense/models/appointment_model.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/models/teacher_model.dart';
import 'package:knocksense/services/appointment_notification_extension.dart';

class AppointmentService {
  final FirebaseDatabase _database;
  static const int MAX_APPOINTMENTS_PER_TEACHER = 3;

  StreamSubscription? _appointmentMonitorSubscription;
  final Set<String> _monitoredAppointments = {};

  void _startDailyResetMonitoring() {
  // Check immediately on service start
  _checkAndCancelUntouchedAppointments();
  
  // Then check every minute to catch the 6:30 AM reset
  Timer.periodic(const Duration(minutes: 1), (timer) {
    final now = DateTime.now();
    // Trigger auto-cancel at 6:30 AM
    if (now.hour == 6 && now.minute == 30) {
      _checkAndCancelUntouchedAppointments();
    }
  });
}

// NEW: Check and cancel untouched appointments from previous day
Future<void> _checkAndCancelUntouchedAppointments() async {
  try {
    final now = DateTime.now();
    
    DateTime lastReset = DateTime(now.year, now.month, now.day, 6, 30);
    if (now.isBefore(lastReset)) {
      lastReset = lastReset.subtract(const Duration(days: 1));
    }
    
    final snapshot = await _database.ref('teacher_appointments').get();
    if (!snapshot.exists || snapshot.value == null) return;
    
    final teacherData = Map<String, dynamic>.from(snapshot.value as Map);
    
    for (var teacherEntry in teacherData.entries) {
      final teacherUid = teacherEntry.key;
      final appointments = Map<String, dynamic>.from(teacherEntry.value as Map);
      
      for (var appointmentEntry in appointments.entries) {
        final appointmentId = appointmentEntry.key;
        final indexData = Map<String, dynamic>.from(appointmentEntry.value as Map);
        
        final studentNumber = indexData['studentNumber'] as String;
        final appointmentSnapshot = await _database
            .ref('appointments/$studentNumber/$appointmentId')
            .get();
            
        if (!appointmentSnapshot.exists) continue;
        
        final appointmentData = Map<String, dynamic>.from(
          appointmentSnapshot.value as Map
        );
        
        if (_shouldAutoCancelAppointment(appointmentData, lastReset, now)) {
          // ✅ FIX: Extract teacher name before auto-rejecting
          // final teacherName = appointmentData['teacherName'] ?? 'Your professor';
          
          await _autoRejectAppointment(
            studentNumber: studentNumber,
            appointmentId: appointmentId,
            teacherUid: teacherUid,
            reason: "Appointment was not processed by the professor before the daily reset (6:30 AM). Please schedule a new appointment.",
          );
          
          debugPrint('🗑️ Auto-cancelled untouched appointment $appointmentId at 6:30 AM reset');
        }
      }
    }
  } catch (e) {
    debugPrint('❌ Error in daily reset auto-cancel: $e');
  }
}

Future<void> _cleanupScheduledNotifications(String appointmentId) async {
  try {
    // Remove the new, idempotent scheduled jobs by their deterministic keys
    final dueNotificationKey = 'due_$appointmentId';
    await _database.ref('scheduled_notifications/$dueNotificationKey').remove();

    final rejectionNotificationKey = 'rejection_$appointmentId';
    await _database.ref('scheduled_notifications/$rejectionNotificationKey').remove();

    final reminderNotificationKey = 'reminder_$appointmentId';
    await _database.ref('scheduled_notifications/$reminderNotificationKey').remove();

    // Also clean up any old notifications that might have been created with .push()
    final snapshot = await _database
        .ref('scheduled_notifications')
        .orderByChild('appointmentId')
        .equalTo(appointmentId)
        .get();
    
    if (snapshot.exists && snapshot.value != null) {
      final notifications = Map<String, dynamic>.from(snapshot.value as Map);
      
      for (var notificationId in notifications.keys) {
        await _database
            .ref('scheduled_notifications/$notificationId')
            .remove();
      }
    }
    
    debugPrint('✅ Cleaned up scheduled notifications for appointment $appointmentId');
  } catch (e) {
    debugPrint('❌ Error cleaning up scheduled notifications: $e');
  }
}

// NEW: Determine if an appointment should be auto-cancelled at reset
// NEW: Determine if an appointment should be auto-cancelled at reset
bool _shouldAutoCancelAppointment(
  Map<String, dynamic> appointmentData, 
  DateTime lastReset,
  DateTime now,
) {
  // Only cancel if still pending
  if (appointmentData['status'] != AppointmentStatus.pending.name) {
    return false;
  }
  
  // Get creation time
  final createdAt = appointmentData['createdAt'];
  if (createdAt == null) return false;
  
  final createdDateTime = DateTime.fromMillisecondsSinceEpoch(createdAt as int);
  
  // Check if appointment was created before the last reset (6:30 AM)
  if (createdDateTime.isBefore(lastReset)) {
    final isScheduled = appointmentData['isScheduled'] ?? false;
    final scheduledTime = appointmentData['scheduledTime'];
    
    if (isScheduled && scheduledTime != null) {
      final scheduledDateTime = DateTime.fromMillisecondsSinceEpoch(scheduledTime as int);
      
      // ✅ KEY FIX: More sophisticated logic for scheduled appointments
      
      // Get the reset that applies to the scheduled time
      final scheduledDateReset = DateTime(
        scheduledDateTime.year, 
        scheduledDateTime.month, 
        scheduledDateTime.day, 
        6, 30
      );
      
      // CASE 1: Scheduled time is in the future (beyond today's reset)
      // These should NEVER be auto-cancelled at the current reset
      if (scheduledDateTime.isAfter(scheduledDateReset)) {
        debugPrint('🔍 Auto-cancel check: Future scheduled appointment (after its day\'s reset) - KEEP IT');
        return false;
      }
      
      // CASE 2: Scheduled time has already passed
      if (scheduledDateTime.isBefore(now)) {
        debugPrint('🔍 Auto-cancel check: Scheduled time has passed');
        return true;
      }
      
      // CASE 3: Created before today's reset, but scheduled for today after the reset
      // Example: Created yesterday, scheduled for today at 11 AM
      // These should NOT be cancelled - they're valid future appointments
      if (scheduledDateTime.isAfter(lastReset) && scheduledDateTime.isAfter(now)) {
        debugPrint('🔍 Auto-cancel check: Valid future appointment scheduled for today - KEEP IT');
        return false;
      }
      
      // CASE 4: Same-day immediate scheduling (professor was online)
      // Example: Created at 3 PM, scheduled for 4 PM same day
      // These should be cancelled if untouched at next reset
      final createdDate = DateTime(
        createdDateTime.year, 
        createdDateTime.month, 
        createdDateTime.day
      );
      final scheduledDate = DateTime(
        scheduledDateTime.year, 
        scheduledDateTime.month, 
        scheduledDateTime.day
      );
      
      if (scheduledDate.isAtSameMomentAs(createdDate)) {
        // Additional check: was it created AND scheduled before the reset?
        final createdDateReset = DateTime(
          createdDate.year,
          createdDate.month,
          createdDate.day,
          6, 30
        );
        
        if (createdDateTime.isBefore(createdDateReset) && 
            scheduledDateTime.isBefore(createdDateReset)) {
          // Both happened before the reset - this is from previous day
          debugPrint('🔍 Auto-cancel check: Same-day appointment from before reset');
          return true;
        }
      }
    }
    
    // Non-scheduled appointments from before reset should be cancelled
    debugPrint('🔍 Auto-cancel check: Non-scheduled appointment from before reset');
    return true;
  }
  
  return false;
}

  AppointmentService({required FirebaseDatabase database})
      : _database = database {
    _startAppointmentMonitoring();
    _startDailyResetMonitoring(); 
  }

  String _cleanName(String name) {
    return name.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
  }

  Future<String?> _getUserPhotoUrl(String uid) async {
    try {
      final userSnapshot = await _database.ref('users/$uid').get();
      if (userSnapshot.exists) {
        final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
        return userData['photoUrl'] as String?;
      }
    } catch (e) {
      debugPrint('Error fetching user photo: $e');
    }
    return null;
  }

  // MODIFIED: Logic updated to reset the count daily at 6:30 AM.
  Future<int> getTodaysAppointmentCount({
    required String studentNumber,
    required String teacherUid,
  }) async {
    try {
      final now = DateTime.now();
      // Set the reset time for today at 6:30 AM
      DateTime todayReset = DateTime(now.year, now.month, now.day, 6, 30);

      DateTime startOfAppointmentDay;
      if (now.isBefore(todayReset)) {
        // If it's before 6:30 AM, the "day" started yesterday at 6:30 AM
        startOfAppointmentDay = todayReset.subtract(const Duration(days: 1));
      } else {
        // If it's at or after 6:30 AM, the "day" started today at 6:30 AM
        startOfAppointmentDay = todayReset;
      }
      final startOfAppointmentDayMillis =
          startOfAppointmentDay.millisecondsSinceEpoch;

      final snapshot = await _database
          .ref('appointments/$studentNumber')
          .orderByChild('teacherUid')
          .equalTo(teacherUid)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return 0;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      int todaysCount = 0;

      for (var entry in data.values) {
        final appointment = Map<String, dynamic>.from(entry as Map);
        if (appointment['createdAt'] is int) {
          final createdAt = appointment['createdAt'] as int;
          // Check if the appointment was created within the current cycle
          if (createdAt >= startOfAppointmentDayMillis) {
            todaysCount++;
          }
        }
      }

      return todaysCount;
    } catch (e) {
      debugPrint('Error getting today\'s appointment count: $e');
      return 3; // Fail safe by returning max count to prevent new appointments
    }
  }

  

  // Updated create appointment method with scheduling
  Future<Map<String, dynamic>> createAppointment({
    required UserModel student,
    required TeacherModel teacher,
    String? studentNote,
    DateTime? scheduledTime,
    bool isScheduled = false,
    bool isSpecial = false,
  }) async {
    try {
      if (student.studentNumber == null) {
        return {
          'success': false,
          'error': 'Student number is required for appointment',
        };
      }
      
      // ✅ PROBLEM 1 FIX: Check the timestamp of the last appointment
      final lastAppointmentSnapshot = await _database
          .ref('appointments/${student.studentNumber}')
          .orderByChild('createdAt')
          .limitToLast(1)
          .get();

      if (lastAppointmentSnapshot.exists) {
        final lastAppointmentData = Map<String, dynamic>.from(
          (lastAppointmentSnapshot.value as Map).values.first
        );
        final lastCreatedAt = DateTime.fromMillisecondsSinceEpoch(lastAppointmentData['createdAt']);
        final now = DateTime.now();
        
        if (now.difference(lastCreatedAt).inMinutes < 4) {
          return {
            'success': false,
            'error': 'You must wait at least 4 minutes before creating another appointment with this teacher.',
          };
        }
      }

      final todaysCount = await getTodaysAppointmentCount(
        studentNumber: student.studentNumber!,
        teacherUid: teacher.uid,
      );
      
      if (todaysCount >= MAX_APPOINTMENTS_PER_TEACHER) {
        return {
          'success': false,
          'error': 'You have reached the daily maximum of $MAX_APPOINTMENTS_PER_TEACHER appointments with this teacher. Please try again tomorrow.',
        };
      }

      
      final hasPending = await hasPendingAppointmentStream(
        studentNumber: student.studentNumber!,
        teacherUid: teacher.uid,
      ).first;
      
      if (hasPending) {
        return {
          'success': false,
          'error': 'You already have a pending appointment with this teacher.',
        };
      }

      final appointmentRef = _database
          .ref('appointments/${student.studentNumber}')
          .push();

      final studentPhotoUrl = await _getUserPhotoUrl(student.uid);

      // If no scheduled time provided for immediate appointment, use now
      final effectiveScheduledTime = scheduledTime ?? 
          (teacher.activeStatus.toLowerCase() == 'online' ? null : DateTime.now());

      final appointmentData = {
        'studentUid': student.uid,
        'studentNumber': student.studentNumber!,
        'studentName': _cleanName(student.displayName),
        'studentPhotoUrl': studentPhotoUrl,
        'teacherUid': teacher.uid,
        'teacherName': _cleanName(teacher.displayName),
        'teacherPhotoUrl': teacher.photoUrl,
        'status': AppointmentStatus.pending.name,
        'createdAt': ServerValue.timestamp,
        'studentNote': studentNote,
        'scheduledTime': effectiveScheduledTime?.millisecondsSinceEpoch,
        'isScheduled': isScheduled,
        'isSpecial': isSpecial,
        'notificationSent': false,
      };

      await appointmentRef.set(appointmentData);

      await _database
          .ref('teacher_appointments/${teacher.uid}/${appointmentRef.key}')
          .set({
        'studentNumber': student.studentNumber,
        'appointmentId': appointmentRef.key,
        'status': AppointmentStatus.pending.name,
        'createdAt': ServerValue.timestamp,
        'scheduledTime': effectiveScheduledTime?.millisecondsSinceEpoch,
        'isScheduled': isScheduled,
        'isSpecial': isSpecial,
      });


      debugPrint('📋 Appointment created - Type: ${isScheduled ? "Scheduled" : "Immediate"}');
      debugPrint('📋 Teacher status: ${teacher.activeStatus}');
      debugPrint('📋 Effective scheduled time: $effectiveScheduledTime');
      debugPrint('📋 isScheduled flag: $isScheduled');

      // Send notification based on appointment type
      final shouldUseScheduledFlow = isScheduled && scheduledTime != null && !isSpecial;

      if (shouldUseScheduledFlow) {
        // Professor was offline/busy - send scheduled notification
        await _sendScheduledNotificationToTeacher(teacher.uid, student.displayName, scheduledTime);
        await _sendScheduledAppointmentReminder(
          teacher.uid, 
          student.displayName, 
          scheduledTime,
          appointmentRef.key!,
          student.studentNumber!,
        );
        
        // Create user notification for scheduled appointment
        await _database.notifyTeacherOfScheduledAppointment(
          teacherUid: teacher.uid,
          studentName: student.displayName,
          appointmentId: appointmentRef.key!,
          studentNumber: student.studentNumber!,
          scheduledTime: scheduledTime,
        );
      } else {
        // Special appointments always go through the immediate flow
        debugPrint('📢 Sending immediate appointment notification to professor ${teacher.uid} (special: $isSpecial)');
        await _sendImmediateAppointmentNotificationToTeacher(
          teacher.uid,
          student.displayName,
          isSpecial: isSpecial,
        );
        
        // Create user notification for immediate appointment
        await _database.notifyTeacherOfImmediateAppointment(
          teacherUid: teacher.uid,
          studentName: student.displayName,
          appointmentId: appointmentRef.key!,
          studentNumber: student.studentNumber!,
          isSpecial: isSpecial,
        );
      }

      return {
        'success': true,
        'appointmentId': appointmentRef.key,
      };
    } catch (e) {
      debugPrint('Error creating appointment: $e');
      return {
        'success': false,
        'error': 'Failed to create appointment: $e',
      };
    }
  }

   void _startAppointmentMonitoring() {
  // Listen to all scheduled appointments
  _appointmentMonitorSubscription = _database
      .ref('teacher_appointments')
      .onValue
      .listen((event) => _handleAppointmentChanges(event));
}

Future<void> _handleAppointmentChanges(DatabaseEvent event) async {
  if (!event.snapshot.exists || event.snapshot.value == null) return;
  
  final now = DateTime.now();
  final teacherData = Map<String, dynamic>.from(event.snapshot.value as Map);
  
  for (var teacherEntry in teacherData.entries) {
    final teacherUid = teacherEntry.key;
    final appointments = Map<String, dynamic>.from(teacherEntry.value as Map);
    
    for (var appointmentEntry in appointments.entries) {
      final appointmentId = appointmentEntry.key;
      final indexData = Map<String, dynamic>.from(appointmentEntry.value as Map);
      final studentNumber = indexData['studentNumber'] as String;
      
      // =============================================================
      // PART 1: MONITOR SCHEDULED APPOINTMENTS
      // =============================================================
      if (indexData['isScheduled'] == true && 
          indexData['scheduledTime'] != null &&
          indexData['status'] == AppointmentStatus.pending.name) {
        
        // ✅ FIX: Add scheduled time to unique key to prevent duplicate monitoring
        // when appointment transitions from future to today
        final scheduledTime = DateTime.fromMillisecondsSinceEpoch(
          indexData['scheduledTime'] as int
        );
        final uniqueKey = '$teacherUid-$appointmentId-${scheduledTime.millisecondsSinceEpoch}';
        
        // Skip if already monitoring this appointment
        if (_monitoredAppointments.contains(uniqueKey)) {
          debugPrint('⏭️ Skipping already monitored appointment: $appointmentId');
          continue;
        }
        
        // Rest of scheduled appointment monitoring logic...
        // (notification scheduling, auto-rejection, etc.)
        
        // Get student name for notifications
        String studentName = 'A student';
        try {
          final appointmentSnapshot = await _database
              .ref('appointments/$studentNumber/$appointmentId')
              .get();
          if (appointmentSnapshot.exists) {
            final appointmentData = Map<String, dynamic>.from(appointmentSnapshot.value as Map);
            studentName = (appointmentData['studentName'] as String?)
                ?.replaceAll(RegExp(r'\s*\(.*?\)'), '')
                .trim() ?? 'A student';
          }
        } catch (e) {
          debugPrint('Could not fetch student name: $e');
        }
        
        // Calculate delays...
        final notificationTime = scheduledTime;
        final notificationDelay = notificationTime.difference(now);
        final autoRejectTime = scheduledTime.add(const Duration(minutes: 2));
        final autoRejectDelay = autoRejectTime.difference(now);
        
        _monitoredAppointments.add(uniqueKey); // ✅ Add with full unique key
        
        // 1. Schedule the "DUE" notification using the backend scheduler.
        // This is more reliable than a client-side Timer and idempotent.
        final String dueNotificationBody = '$studentName\'s appointment time has arrived. You have 2 minutes to respond or it will be auto-cancelled.';
        final dueNotificationKey = 'due_$appointmentId';
        await _database.ref('scheduled_notifications/$dueNotificationKey').set({
          'notificationId': dueNotificationKey,
          'teacherUid': teacherUid,
          'appointmentId': appointmentId,
          'type': 'scheduled_appointment_due',
          'scheduledFor': scheduledTime.millisecondsSinceEpoch,
          'title': '⏰ Scheduled Appointment Ready',
          'body': dueNotificationBody,
          'studentNumber': studentNumber, // Add studentNumber for user notification creation
          'data': {
            'type': 'scheduled_appointment_due',
            'studentName': studentName,
            'appointmentId': appointmentId,
            'urgency': 'high',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'bigText': dueNotificationBody,
          },
          'createdAt': ServerValue.timestamp,
        });
        
        // NOTE: User notification creation moved to cloud function that processes scheduled_notifications
        // This prevents duplicate notifications. The cloud function will create both FCM and user notifications
        // when the scheduled time arrives. See: scheduled_notifications cloud function processor.
        
        // Schedule auto-rejection
        if (autoRejectDelay.isNegative) {
          await _autoRejectAppointment(
            studentNumber: studentNumber,
            appointmentId: appointmentId,
            teacherUid: teacherUid,
            reason: "The professor hasn't been able to accept or deny the scheduled meeting request.",
          );
          debugPrint('🗑️ Auto-rejected expired appointment $appointmentId immediately');
          _monitoredAppointments.remove(uniqueKey); // ✅ Clean up
        } else {
          Timer(autoRejectDelay, () async {
            final snapshot = await _database
                .ref('teacher_appointments/$teacherUid/$appointmentId')
                .get();
            
            if (snapshot.exists) {
              final data = Map<String, dynamic>.from(snapshot.value as Map);
              if (data['status'] == AppointmentStatus.pending.name) {
                await _autoRejectAppointment(
                  studentNumber: data['studentNumber'] as String,
                  appointmentId: appointmentId,
                  teacherUid: teacherUid,
                  reason: "The professor hasn't been able to accept or deny the scheduled meeting request.",
                );
                debugPrint('🗑️ Auto-rejected appointment $appointmentId after 2 minutes');
              }
            }
            _monitoredAppointments.remove(uniqueKey); // ✅ Clean up
          });
        }
      }
      
      // =============================================================
      // PART 2: MONITOR WAIT 5 MINUTES APPOINTMENTS
      // =============================================================
      if (indexData['status'] == AppointmentStatus.accepted.name) {
        // Fetch full appointment details to check teacherAction
        try {
          final appointmentSnapshot = await _database
              .ref('appointments/$studentNumber/$appointmentId')
              .get();
          
          if (appointmentSnapshot.exists) {
            final appointmentData = Map<String, dynamic>.from(appointmentSnapshot.value as Map);
            
            // Check if this is a wait5Minutes appointment
            if (appointmentData['teacherAction'] == TeacherAction.wait5Minutes.name) {
              final respondedAt = appointmentData['respondedAt'];
              
              if (respondedAt != null) {
                final respondedTime = DateTime.fromMillisecondsSinceEpoch(respondedAt as int);
                
                // Calculate when the wait period ends (5 minutes after teacher responded)
                final waitEndTime = respondedTime.add(const Duration(minutes: 5));
                
                // Calculate when auto-rejection happens (7 minutes after teacher responded = 5 wait + 2 decision)
                final autoRejectTime = respondedTime.add(const Duration(minutes: 7));
                final autoRejectDelay = autoRejectTime.difference(now);
                
                final uniqueKey = '$teacherUid-$appointmentId-wait';
                
                // Skip if already monitoring this wait appointment
                if (_monitoredAppointments.contains(uniqueKey)) continue;
                
                _monitoredAppointments.add(uniqueKey);
                
                if (autoRejectDelay.isNegative) {
                  // Already past 7 minutes, reject immediately
                  await _autoRejectWaitAppointment(
                    studentNumber: studentNumber,
                    appointmentId: appointmentId,
                    teacherUid: teacherUid,
                  );
                  debugPrint('🗑️ Auto-rejected expired wait appointment $appointmentId immediately');
                  _monitoredAppointments.remove(uniqueKey);
                } else {
                  // Schedule future auto-rejection at 7 minutes
                  Timer(autoRejectDelay, () async {
                    // Check if still in wait5Minutes state before auto-rejecting
                    final snapshot = await _database
                        .ref('appointments/$studentNumber/$appointmentId')
                        .get();
                    
                    if (snapshot.exists) {
                      final data = Map<String, dynamic>.from(snapshot.value as Map);
                      
                      // Only auto-reject if still in wait5Minutes state
                      if (data['teacherAction'] == TeacherAction.wait5Minutes.name &&
                          data['status'] == AppointmentStatus.accepted.name) {
                        await _autoRejectWaitAppointment(
                          studentNumber: studentNumber,
                          appointmentId: appointmentId,
                          teacherUid: teacherUid,
                        );
                        debugPrint('🗑️ Auto-rejected wait appointment $appointmentId after 7 minutes (5 wait + 2 decision)');
                      }
                    }
                    _monitoredAppointments.remove(uniqueKey);
                  });
                  
                  debugPrint('⏰ Scheduled auto-rejection for wait appointment $appointmentId in ${autoRejectDelay.inSeconds} seconds (${(autoRejectDelay.inSeconds / 60).toStringAsFixed(1)} minutes)');
                  debugPrint('   Wait ends at: $waitEndTime');
                  debugPrint('   Auto-reject at: $autoRejectTime');
                }
              }
            }
          }
        } catch (e) {
          debugPrint('❌ Error checking wait5Minutes appointment $appointmentId: $e');
        }
      }
    }
  }
}

Future<void> _autoRejectWaitAppointment({
  required String studentNumber,
  required String appointmentId,
  required String teacherUid,
}) async {
  try {
    final appointmentSnapshot = await _database
        .ref('appointments/$studentNumber/$appointmentId')
        .get();
    
    if (!appointmentSnapshot.exists) return;
    
    final currentData = Map<String, dynamic>.from(appointmentSnapshot.value as Map);
    if (currentData['status'] != AppointmentStatus.accepted.name) return;
    if (currentData['teacherAction'] != TeacherAction.wait5Minutes.name) return;
    
    final updates = <String, dynamic>{};
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final studentUid = currentData['studentUid'] as String?;
    final teacherName = currentData['teacherName'] as String?;
    
    updates['appointments/$studentNumber/$appointmentId/status'] = 
        AppointmentStatus.cancelled.name;
    updates['appointments/$studentNumber/$appointmentId/autoRejected'] = true;
    updates['appointments/$studentNumber/$appointmentId/autoRejectedAt'] = timestamp;
    updates['appointments/$studentNumber/$appointmentId/teacherResponse'] = 
        "The professor did not respond within the 2-minute decision window after your 5-minute wait period.";
    updates['appointments/$studentNumber/$appointmentId/lastModified'] = timestamp;
    
    updates['teacher_appointments/$teacherUid/$appointmentId/status'] = 
        AppointmentStatus.cancelled.name;
    updates['teacher_appointments/$teacherUid/$appointmentId/autoRejected'] = true;
    updates['teacher_appointments/$teacherUid/$appointmentId/lastModified'] = timestamp;
    
    await _database.ref().update(updates);
    
    // Send notification to student
    await _sendWaitAutoRejectionNotification(
      studentNumber: studentNumber,
      studentUid: studentUid,
      teacherName: teacherName,
      appointmentId: appointmentId,
    );
    
    // Clean up scheduled notifications
    await _cleanupScheduledNotifications(appointmentId);
    
    debugPrint('✅ Auto-rejected wait appointment $appointmentId at ${DateTime.fromMillisecondsSinceEpoch(timestamp)}');
  } catch (e) {
    debugPrint('❌ Error auto-rejecting wait appointment: $e');
  }
}

Future<void> _sendWaitAutoRejectionNotification({
  required String studentNumber,
  String? studentUid,
  String? teacherName,
  required String appointmentId,
}) async {
  try {
    String? resolvedStudentUid = studentUid;
    if (resolvedStudentUid == null) {
      final studentSnapshot = await _database
          .ref('roles/student')
          .orderByChild('studentNumber')
          .equalTo(studentNumber)
          .limitToFirst(1)
          .get();
      
      if (!studentSnapshot.exists || studentSnapshot.value == null) {
        debugPrint('⚠️ Student not found for wait auto-rejection notification: $studentNumber');
        return;
      }

      final studentMap = Map<String, dynamic>.from(studentSnapshot.value as Map);
      resolvedStudentUid = studentMap.keys.first;
    }

    if (resolvedStudentUid == null) {
      debugPrint('⚠️ Unable to resolve student UID for wait auto-rejection notification: $studentNumber');
      return;
    }

    String resolvedTeacherName = teacherName ?? 'Your professor';
    resolvedTeacherName = resolvedTeacherName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

    const waitMessage = 'The professor did not respond within the 2-minute decision window after your 5-minute wait period.';
    final String notificationBody = '$resolvedTeacherName did not respond within the decision window after your wait period.';

    await _database.ref('notification_queue').push().set({
      'studentUid': resolvedStudentUid,
      'notification': {
        'title': '⏰ Appointment Cancelled',
        'body': notificationBody,
      },
      'data': {
        'type': 'wait_appointment_auto_cancelled',
        'studentNumber': studentNumber,
        'teacherName': resolvedTeacherName,
        'appointmentId': appointmentId,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'bigText': notificationBody,
      },
      'priority': 'high',
      'createdAt': ServerValue.timestamp,
    });
    
    await _database.notifyStudentAppointmentAutoRejected(
      studentUid: resolvedStudentUid,
      teacherName: resolvedTeacherName,
      message: waitMessage,
    );
    
    debugPrint('✅ Wait auto-rejection notification queued for student $resolvedStudentUid');
  } catch (e) {
    debugPrint('❌ Error sending wait auto-rejection notification: $e');
  }
}

  Future<void> _autoRejectAppointment({
  required String studentNumber,
  required String appointmentId,
  required String teacherUid,
  required String reason,
}) async {
  try {
    // ✅ FIX: Get appointment data BEFORE updating to get correct teacher name
    final appointmentSnapshot = await _database
        .ref('appointments/$studentNumber/$appointmentId')
        .get();
    
    String teacherName = 'Your professor';
    if (appointmentSnapshot.exists) {
      final appointmentData = Map<String, dynamic>.from(appointmentSnapshot.value as Map);
      teacherName = appointmentData['teacherName'] ?? 'Your professor';
      teacherName = teacherName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    }
    
    if (!appointmentSnapshot.exists) {
      debugPrint('Appointment $appointmentId not found, skipping auto-reject');
      return;
    }
    
    final currentData = Map<String, dynamic>.from(appointmentSnapshot.value as Map);
    if (currentData['status'] != AppointmentStatus.pending.name) {
      debugPrint('Appointment $appointmentId is not pending, skipping auto-reject');
      return;
    }
    
    final updates = <String, dynamic>{};
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    updates['appointments/$studentNumber/$appointmentId/status'] = 
        AppointmentStatus.cancelled.name;
    updates['appointments/$studentNumber/$appointmentId/autoRejected'] = true;
    updates['appointments/$studentNumber/$appointmentId/autoRejectedAt'] = timestamp;
    updates['appointments/$studentNumber/$appointmentId/teacherResponse'] = reason;
    updates['appointments/$studentNumber/$appointmentId/lastModified'] = timestamp;
    
    updates['teacher_appointments/$teacherUid/$appointmentId/status'] = 
        AppointmentStatus.cancelled.name;
    updates['teacher_appointments/$teacherUid/$appointmentId/autoRejected'] = true;
    updates['teacher_appointments/$teacherUid/$appointmentId/lastModified'] = timestamp;
    updates['teacher_appointments/$teacherUid/$appointmentId/autoRejectedAt'] = timestamp;
    
    await _database.ref().update(updates);
    
    // ✅ FIX: Pass the correct teacher name to notification
    await _sendAutoRejectionNotification(studentNumber, reason, teacherName);
    
    // Create user notification for auto-rejected appointment
    final studentUid = currentData['studentUid'] as String?;
    if (studentUid != null) {
      await _database.notifyStudentAppointmentAutoRejected(
        studentUid: studentUid,
        teacherName: teacherName,
        message: reason,
      );
    }
    
    await _cleanupScheduledNotifications(appointmentId);
    
    final uniqueKey = '$teacherUid-$appointmentId';
    _monitoredAppointments.remove(uniqueKey);
    
    debugPrint('✅ Auto-rejected appointment $appointmentId for student $studentNumber at ${DateTime.fromMillisecondsSinceEpoch(timestamp)}');
  } catch (e) {
    debugPrint('❌ Error auto-rejecting appointment: $e');
  }
}

  // Get today's appointments for teacher
// In appointment_service.dart
// Updated getTeacherTodayAppointments method

Stream<List<AppointmentModel>> getTeacherTodayAppointments(String teacherUid) {
  final ref = _database.ref('teacher_appointments/$teacherUid');

  return ref.onValue.asyncMap((event) async {
    if (!event.snapshot.exists || event.snapshot.value == null) {
      return [];
    }

    final indexData = Map<String, dynamic>.from(event.snapshot.value as Map);
    final List<Future<AppointmentModel?>> appointmentFutures = [];

    for (var entry in indexData.entries) {
      final appointmentIndex = Map<String, dynamic>.from(entry.value as Map);
      final studentNumber = appointmentIndex['studentNumber'] as String;
      final appointmentId = appointmentIndex['appointmentId'] as String;

      appointmentFutures.add(
        _fetchAppointmentDetails(studentNumber, appointmentId),
      );
    }

    final appointmentsNullable = await Future.wait(appointmentFutures);
    final appointments = appointmentsNullable.whereType<AppointmentModel>().toList();

    final now = DateTime.now();
    
    // ✅ FIX: Calculate the "appointment day" boundary (6:30 AM)
    final todayReset = DateTime(now.year, now.month, now.day, 6, 30);
    
    // Determine the start of the current "appointment day"
    final DateTime appointmentDayStart;
    if (now.isBefore(todayReset)) {
      // Before 6:30 AM - we're still in "yesterday's" appointment day
      appointmentDayStart = todayReset.subtract(const Duration(days: 1));
    } else {
      // After 6:30 AM - we're in "today's" appointment day
      appointmentDayStart = todayReset;
    }
    
    // Calculate the end of the current appointment day (next day at 6:30 AM)
    final appointmentDayEnd = appointmentDayStart.add(const Duration(days: 1));
    
    debugPrint('📅 Appointment Day Window: ${appointmentDayStart} to ${appointmentDayEnd}');
    
    final List<AppointmentModel> filteredAppointments = [];

    for (var appointment in appointments) {
      // Skip cancelled, denied, AND completed appointments
      if (appointment.status == AppointmentStatus.cancelled ||
          appointment.status == AppointmentStatus.denied ||
          appointment.status == AppointmentStatus.completed) {
        continue;
      }
      
      bool shouldInclude = false;

      // Check if it's a scheduled appointment
      if (appointment.scheduledTime != null) {
        final scheduledDateTime = appointment.scheduledTime!;
        
        // ✅ FIX: Check if scheduled time is within the current appointment day window
        final isWithinAppointmentDay = 
            (scheduledDateTime.isAtSameMomentAs(appointmentDayStart) || 
             scheduledDateTime.isAfter(appointmentDayStart)) &&
            scheduledDateTime.isBefore(appointmentDayEnd);
        
        if (isWithinAppointmentDay) {
          // Check if scheduled appointment has expired
          final expirationTime = scheduledDateTime.add(const Duration(minutes: 2));
          
          // Check for auto-rejection conditions
          if (now.isAfter(expirationTime) && 
              appointment.status == AppointmentStatus.pending) {
            // This appointment should be auto-rejected, skip it
            debugPrint('⏰ Skipping expired pending appointment ${appointment.appointmentId}');
            
            // Trigger auto-rejection if not already done
            final uniqueKey = '$teacherUid-${appointment.appointmentId}';
            if (!_monitoredAppointments.contains(uniqueKey)) {
              _monitoredAppointments.add(uniqueKey);
              Future.microtask(() => _autoRejectAppointment(
                studentNumber: appointment.studentNumber,
                appointmentId: appointment.appointmentId,
                teacherUid: teacherUid,
                reason: "The professor hasn't been able to accept or deny the scheduled meeting request.",
              ));
            }
            continue;
          }
          
          // Include if not expired OR already accepted/in progress
          if (now.isBefore(expirationTime) || 
              appointment.status == AppointmentStatus.accepted) {
            shouldInclude = true;
          }
        }
      } 
      // Also include immediate appointments created within the appointment day
      else if (!appointment.isScheduled) {
        // Check if created within the appointment day window
        final createdDateTime = appointment.createdAt;
        final isCreatedInAppointmentDay = 
            (createdDateTime.isAtSameMomentAs(appointmentDayStart) ||
             createdDateTime.isAfter(appointmentDayStart)) &&
            createdDateTime.isBefore(appointmentDayEnd);
        
        if (isCreatedInAppointmentDay) {
          shouldInclude = true;
        }
      }
      
      if (shouldInclude) {
        filteredAppointments.add(appointment);
      }
    }

    // Sort by priority
    filteredAppointments.sort((a, b) {
      if (a.status == AppointmentStatus.pending && 
          b.status != AppointmentStatus.pending) return -1;
      if (a.status != AppointmentStatus.pending && 
          b.status == AppointmentStatus.pending) return 1;
      
      if (a.isNear && !b.isNear) return -1;
      if (!a.isNear && b.isNear) return 1;
      
      if (a.isScheduled && !b.isScheduled) return -1;
      if (!a.isScheduled && b.isScheduled) return 1;
      
      final aTime = a.scheduledTime ?? a.createdAt;
      final bTime = b.scheduledTime ?? b.createdAt;
      return aTime.compareTo(bTime);
    });

    return filteredAppointments;
  });
}

Future<AppointmentModel?> _fetchAppointmentDetails(String studentNumber, String appointmentId) async {
  final appointmentSnapshot = await _database
      .ref('appointments/$studentNumber/$appointmentId')
      .get();
      
  if (appointmentSnapshot.exists) {
    final appointmentData = Map<String, dynamic>.from(appointmentSnapshot.value as Map);
    
    // Fetch photo URLs in parallel
    final photoUrls = await Future.wait([
      if (appointmentData['studentPhotoUrl'] == null && appointmentData['studentUid'] != null)
        _getUserPhotoUrl(appointmentData['studentUid'])
      else
        Future.value(appointmentData['studentPhotoUrl']),

      if (appointmentData['teacherPhotoUrl'] == null && appointmentData['teacherUid'] != null)
        _getUserPhotoUrl(appointmentData['teacherUid'])
      else
        Future.value(appointmentData['teacherPhotoUrl']),
    ]);

    appointmentData['studentPhotoUrl'] = photoUrls[0];
    appointmentData['teacherPhotoUrl'] = photoUrls[1];
    
    return AppointmentModel.fromJson(appointmentId, appointmentData);
  }
  return null;
}

  Stream<List<AppointmentModel>> getTeacherFutureAppointments(String teacherUid) {
  return _database
      .ref('teacher_appointments/$teacherUid')
      .onValue
      .asyncMap((event) async {
    final List<AppointmentModel> appointments = [];
    
    if (event.snapshot.exists && event.snapshot.value != null) {
      final indexData = Map<String, dynamic>.from(event.snapshot.value as Map);
      
      for (var entry in indexData.entries) {
        final appointmentIndex = Map<String, dynamic>.from(entry.value as Map);
        final studentNumber = appointmentIndex['studentNumber'] as String;
        final appointmentId = appointmentIndex['appointmentId'] as String;
        
        final appointmentSnapshot = await _database
            .ref('appointments/$studentNumber/$appointmentId')
            .get();
            
        if (appointmentSnapshot.exists) {
          final appointmentData = Map<String, dynamic>.from(appointmentSnapshot.value as Map);
          
          if (appointmentData['studentPhotoUrl'] == null && appointmentData['studentUid'] != null) {
            appointmentData['studentPhotoUrl'] = await _getUserPhotoUrl(appointmentData['studentUid']);
          }
          if (appointmentData['teacherPhotoUrl'] == null && appointmentData['teacherUid'] != null) {
            appointmentData['teacherPhotoUrl'] = await _getUserPhotoUrl(appointmentData['teacherUid']);
          }
          
          final appointment = AppointmentModel.fromJson(appointmentId, appointmentData);
          
          // ✅ FIX: Determine if appointment is truly "future"
          if (appointment.scheduledTime != null && 
              appointment.status == AppointmentStatus.pending) {
            
            final now = DateTime.now();
            final scheduledDateTime = appointment.scheduledTime!;
            
            // Calculate today's reset (6:30 AM)
            final todayReset = DateTime(now.year, now.month, now.day, 6, 30);
            
            // Determine the start of the current "appointment day"
            final DateTime appointmentDayStart;
            if (now.isBefore(todayReset)) {
              // Before 6:30 AM - appointment day started yesterday at 6:30 AM
              appointmentDayStart = todayReset.subtract(const Duration(days: 1));
            } else {
              // After 6:30 AM - appointment day started today at 6:30 AM
              appointmentDayStart = todayReset;
            }
            
            // Calculate the end of current appointment day (next day at 6:30 AM)
            final appointmentDayEnd = appointmentDayStart.add(const Duration(days: 1));
            
            // ✅ An appointment is "future" if:
            // 1. It's scheduled for after the current appointment day window
            // 2. OR it's scheduled within today but we haven't hit 6:30 AM yet
            
            final isAfterCurrentAppointmentDay = scheduledDateTime.isAtSameMomentAs(appointmentDayEnd) ||
                                                 scheduledDateTime.isAfter(appointmentDayEnd);
            
            if (isAfterCurrentAppointmentDay) {
              appointments.add(appointment);
              debugPrint('📅 Future appointment: ${appointment.appointmentId} scheduled for ${scheduledDateTime}');
            } else {
              debugPrint('⏭️ Skipping appointment ${appointment.appointmentId} - within current appointment day');
            }
          }
        }
      }
      
      // Sort by scheduled time
      appointments.sort((a, b) {
        final aTime = a.scheduledTime ?? a.createdAt;
        final bTime = b.scheduledTime ?? b.createdAt;
        return aTime.compareTo(bTime);
      });
    }
    
    return appointments;
  });
}


  // Simple accept/reject for scheduled appointments when time is near
   Future<bool> respondToScheduledAppointment({
    required String studentNumber,
    required String appointmentId,
    required String teacherUid,
    required bool accept,
    required String teacherResponse, // Made required for scheduled appointments
  }) async {
    try {

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔧 SERVICE: respondToScheduledAppointment');
      print('   Student: $studentNumber');
      print('   Appointment: $appointmentId');
      print('   Accept: $accept');
      print('   Response: $teacherResponse');



      final updates = <String, dynamic>{};
      
      // ✅ PROBLEM 3 FIX: Change logic to mark as completed on acceptance
      final newStatus = accept ? AppointmentStatus.completed : AppointmentStatus.denied;
      
      updates['appointments/$studentNumber/$appointmentId/status'] = newStatus.name;
      updates['appointments/$studentNumber/$appointmentId/respondedAt'] = ServerValue.timestamp;
      updates['appointments/$studentNumber/$appointmentId/teacherResponse'] = teacherResponse;
      
      // For scheduled appointments, if accepted, treat as "meet now"
      if (accept) {
        // --- OLD CODE (COMMENTED OUT AS REQUESTED) ---
        // updates['appointments/$studentNumber/$appointmentId/teacherAction'] = TeacherAction.meetNow.name;
        // // Mark as completed since it's an immediate meeting
        // updates['appointments/$studentNumber/$appointmentId/completedAt'] = ServerValue.timestamp;

        // --- NEW REPLACEMENT CODE ---
        updates['appointments/$studentNumber/$appointmentId/teacherAction'] = TeacherAction.meetNow.name; // Keep for context
        updates['appointments/$studentNumber/$appointmentId/completedAt'] = ServerValue.timestamp; // Set completion time
      } else {
        updates['appointments/$studentNumber/$appointmentId/teacherAction'] = TeacherAction.reject.name;
      }
      
      updates['teacher_appointments/$teacherUid/$appointmentId/status'] = newStatus.name;
      updates['teacher_appointments/$teacherUid/$appointmentId/respondedAt'] = ServerValue.timestamp;
      
      await _database.ref().update(updates);

      // After making a decision, clear any pending scheduled notifications for this appointment
      await _cleanupScheduledNotifications(appointmentId);

        print('🔧 SERVICE: Updating database...');
        print('   Updates: ${updates.keys.toList()}');

        print('✅ SERVICE: Database updated successfully');
        print('🔧 SERVICE: Now sending notification...');
      
      // Send notification with the teacher's response/location
      await _sendScheduledAppointmentResponse(studentNumber, accept, teacherResponse);
      
      // Create user notification for student
      final appointmentSnapshot = await _database
          .ref('appointments/$studentNumber/$appointmentId')
          .get();
      
      if (appointmentSnapshot.exists) {
        final appointmentData = Map<String, dynamic>.from(appointmentSnapshot.value as Map);
        final studentUid = appointmentData['studentUid'] as String?;
        final teacherName = appointmentData['teacherName'] as String? ?? 'Your professor';
        
        if (studentUid != null) {
          if (accept) {
            await _database.notifyStudentAppointmentAccepted(
              studentUid: studentUid,
              teacherName: teacherName,
              action: TeacherAction.meetNow,
              teacherResponse: teacherResponse,
            );
          } else {
            await _database.notifyStudentAppointmentRejected(
              studentUid: studentUid,
              teacherName: teacherName,
              teacherResponse: teacherResponse,
            );
          }
        }
      }

       print('✅ SERVICE: Notification method called');
       print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        
      
      return true;
    } catch (e) {

       print('✅ SERVICE: Notification method called');
       print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
      debugPrint('Error responding to scheduled appointment: $e');
      return false;
    }
  }

  Future<bool> respondToSpecialAppointment({
    required String studentNumber,
    required String appointmentId,
    required String teacherUid,
    required bool accept,
    String? teacherResponse,
  }) async {
    try {
      final appointmentSnapshot = await _database
          .ref('appointments/$studentNumber/$appointmentId')
          .get();

      if (!appointmentSnapshot.exists) {
        debugPrint('Special appointment not found');
        return false;
      }

      final appointmentData = Map<String, dynamic>.from(appointmentSnapshot.value as Map);

      if (appointmentData['status'] != AppointmentStatus.pending.name) {
        debugPrint('Special appointment already processed');
        return false;
      }

      final updates = <String, dynamic>{};
      
      // For special appointments: accept = completed, reject = denied
      final action = accept ? TeacherAction.meetNow : TeacherAction.reject;
      final newStatus = accept ? AppointmentStatus.completed : AppointmentStatus.denied;

      updates['appointments/$studentNumber/$appointmentId/status'] = newStatus.name;
      updates['appointments/$studentNumber/$appointmentId/respondedAt'] = ServerValue.timestamp;
      updates['appointments/$studentNumber/$appointmentId/teacherAction'] = action.name;

      if (teacherResponse != null && teacherResponse.isNotEmpty) {
        updates['appointments/$studentNumber/$appointmentId/teacherResponse'] = teacherResponse;
      }

      // Mark as completed on teacher side when accepted
      updates['teacher_appointments/$teacherUid/$appointmentId/status'] = newStatus.name;
      updates['teacher_appointments/$teacherUid/$appointmentId/respondedAt'] = ServerValue.timestamp;
      updates['teacher_appointments/$teacherUid/$appointmentId/teacherAction'] = action.name;
      
      if (accept) {
        updates['appointments/$studentNumber/$appointmentId/completedAt'] = ServerValue.timestamp;
        updates['teacher_appointments/$teacherUid/$appointmentId/completedAt'] = ServerValue.timestamp;
      }

      await _database.ref().update(updates);

      await _sendNotificationToStudent(studentNumber, action, teacherResponse);

      final studentUid = appointmentData['studentUid'] as String?;
      final teacherName = (appointmentData['teacherName'] as String? ?? 'Your professor')
          .replaceAll(RegExp(r'\s*\(.*?\)'), '')
          .trim();

      if (studentUid != null) {
        if (accept) {
          await _database.notifyStudentAppointmentAccepted(
            studentUid: studentUid,
            teacherName: teacherName,
            action: action,
            teacherResponse: teacherResponse,
          );
        } else {
          await _database.notifyStudentAppointmentRejected(
            studentUid: studentUid,
            teacherName: teacherName,
            teacherResponse: teacherResponse,
          );
        }
      }

      await _cleanupScheduledNotifications(appointmentId);

      return true;
    } catch (e) {
      debugPrint('Error responding to special appointment: $e');
      return false;
    }
  }

  // Keep existing respond method for today's appointments
  Future<bool> respondToAppointment({
    required String studentNumber,
    required String appointmentId,
    required String teacherUid,
    required TeacherAction action,
    String? teacherResponse,
    DateTime? scheduledTime,
  }) async {
    try {
      final appointmentSnapshot = await _database
          .ref('appointments/$studentNumber/$appointmentId')
          .get();
          
      if (!appointmentSnapshot.exists) {
        debugPrint('Appointment not found');
        return false;
      }
      
      final updates = <String, dynamic>{};
      
      AppointmentStatus newStatus;
      switch (action) {
        case TeacherAction.reject:
          newStatus = AppointmentStatus.denied;
          break;
        case TeacherAction.meetNow:
        case TeacherAction.wait5Minutes:
        case TeacherAction.meetLater:
          newStatus = AppointmentStatus.accepted;
          break;
        default:
          newStatus = AppointmentStatus.pending;
      }

      updates['appointments/$studentNumber/$appointmentId/status'] = newStatus.name;
      updates['appointments/$studentNumber/$appointmentId/respondedAt'] = ServerValue.timestamp;
      updates['appointments/$studentNumber/$appointmentId/teacherAction'] = action.name;
      
      if (teacherResponse != null) {
        updates['appointments/$studentNumber/$appointmentId/teacherResponse'] = teacherResponse;
      }
      
      if (scheduledTime != null && action == TeacherAction.meetLater) {
        updates['appointments/$studentNumber/$appointmentId/scheduledTime'] = 
            scheduledTime.millisecondsSinceEpoch;
      }

      updates['teacher_appointments/$teacherUid/$appointmentId/status'] = newStatus.name;
      updates['teacher_appointments/$teacherUid/$appointmentId/respondedAt'] = ServerValue.timestamp;

      await _database.ref().update(updates);

      await _sendNotificationToStudent(studentNumber, action, teacherResponse);
      
      // Create user notification for student
      final appointmentData = Map<String, dynamic>.from(appointmentSnapshot.value as Map);
      final studentUid = appointmentData['studentUid'] as String?;
      final teacherName = appointmentData['teacherName'] as String? ?? 'Your professor';
      
      if (studentUid != null) {
        if (action == TeacherAction.reject) {
          await _database.notifyStudentAppointmentRejected(
            studentUid: studentUid,
            teacherName: teacherName,
            teacherResponse: teacherResponse,
          );
        } else {
          await _database.notifyStudentAppointmentAccepted(
            studentUid: studentUid,
            teacherName: teacherName,
            action: action,
            teacherResponse: teacherResponse,
          );
        }
      }

      if (action == TeacherAction.wait5Minutes) {
        await _scheduleWaitReminder(studentNumber, appointmentId, 5, teacherUid);
      } else {
        await _cleanupScheduledNotifications(appointmentId);
      }

      return true;
    } catch (e) {
      debugPrint('Error responding to appointment: $e');
      return false;
    }
  }

  // Existing methods remain mostly the same
  Stream<List<AppointmentModel>> getTeacherActiveAppointments(String teacherUid) {
    return getTeacherTodayAppointments(teacherUid);
  }

  Stream<List<AppointmentModel>> getTeacherPendingAppointments(String teacherUid) {
    return getTeacherTodayAppointments(teacherUid);
  }

  Stream<List<AppointmentModel>> getTeacherAllAppointments(String teacherUid) {
    return _database
        .ref('teacher_appointments/$teacherUid')
        .onValue
        .asyncMap((event) async {
      final List<AppointmentModel> appointments = [];
      
      if (event.snapshot.exists && event.snapshot.value != null) {
        final indexData = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        for (var entry in indexData.entries) {
          final appointmentIndex = Map<String, dynamic>.from(entry.value as Map);
          final studentNumber = appointmentIndex['studentNumber'] as String;
          final appointmentId = appointmentIndex['appointmentId'] as String;
          
          final appointmentSnapshot = await _database
              .ref('appointments/$studentNumber/$appointmentId')
              .get();
              
          if (appointmentSnapshot.exists) {
            final appointmentData = Map<String, dynamic>.from(appointmentSnapshot.value as Map);
            
            if (appointmentData['studentPhotoUrl'] == null && appointmentData['studentUid'] != null) {
              appointmentData['studentPhotoUrl'] = await _getUserPhotoUrl(appointmentData['studentUid']);
            }
            if (appointmentData['teacherPhotoUrl'] == null && appointmentData['teacherUid'] != null) {
              appointmentData['teacherPhotoUrl'] = await _getUserPhotoUrl(appointmentData['teacherUid']);
            }
            
            appointments.add(AppointmentModel.fromJson(appointmentId, appointmentData));
          }
        }
        
        appointments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      
      return appointments;
    });
  }

  Stream<List<AppointmentModel>> getStudentAppointments(String studentNumber, {
    DateTimeRange? dateRange,
  }) {
    return _database
        .ref('appointments/$studentNumber')
        .orderByChild('createdAt')
        .onValue
        .asyncMap((event) async {
      final List<AppointmentModel> appointments = [];
      
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        for (var entry in data.entries) {
          try {
            final appointmentData = Map<String, dynamic>.from(entry.value as Map);
            
            if (appointmentData['studentPhotoUrl'] == null && appointmentData['studentUid'] != null) {
              appointmentData['studentPhotoUrl'] = await _getUserPhotoUrl(appointmentData['studentUid']);
            }
            if (appointmentData['teacherPhotoUrl'] == null && appointmentData['teacherUid'] != null) {
              appointmentData['teacherPhotoUrl'] = await _getUserPhotoUrl(appointmentData['teacherUid']);
            }
            
            final appointment = AppointmentModel.fromJson(entry.key, appointmentData);
            appointments.add(appointment);
          } catch (e) {
            print('Error parsing appointment ${entry.key}: $e');
          }
        }
        
        appointments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      
      return appointments;
    });
  }

  Future<bool> cancelAppointment({
  required String studentNumber,
  required String appointmentId,
  required String teacherUid,
  String? reason,
}) async {
  try {
    // First, get the teacher's name from the appointment
    final appointmentSnapshot = await _database
        .ref('appointments/$studentNumber/$appointmentId')
        .get();
    
    String teacherName = 'Your professor';
    if (appointmentSnapshot.exists) {
      final appointmentData = Map<String, dynamic>.from(appointmentSnapshot.value as Map);
      teacherName = appointmentData['teacherName'] ?? 'Your professor';
    }

    final updates = <String, dynamic>{};

    updates['appointments/$studentNumber/$appointmentId/status'] =
        AppointmentStatus.cancelled.name;
    updates['teacher_appointments/$teacherUid/$appointmentId/status'] =
        AppointmentStatus.cancelled.name;
    updates['appointments/$studentNumber/$appointmentId/cancelledAt'] =
        ServerValue.timestamp;

    if (reason != null && reason.isNotEmpty) {
      updates['appointments/$studentNumber/$appointmentId/teacherResponse'] = reason;
    }

    await _database.ref().update(updates);

    await _cleanupScheduledNotifications(appointmentId);

    // Send descriptive cancellation notification
    await _sendCancellationNotification(
      studentNumber,
      teacherName,
      reason ?? 'No reason provided.',
    );
    
    // Create user notification for cancelled appointment
    if (appointmentSnapshot.exists) {
      final appointmentData = Map<String, dynamic>.from(appointmentSnapshot.value as Map);
      final studentUid = appointmentData['studentUid'] as String?;
      
      if (studentUid != null) {
        await _database.notifyStudentAppointmentCancelled(
          studentUid: studentUid,
          teacherName: teacherName,
          reason: reason ?? 'No reason provided.',
        );
      }
    }

    return true;
  } catch (e) {
    debugPrint('Error cancelling appointment: $e');
    return false;
  }
}

  Future<bool> completeAppointment({
  required String studentNumber,
  required String appointmentId,
  required String teacherUid,
}) async {
  try {
    final updates = <String, dynamic>{};
    
    updates['appointments/$studentNumber/$appointmentId/status'] = 
        AppointmentStatus.completed.name;
    updates['teacher_appointments/$teacherUid/$appointmentId/status'] = 
        AppointmentStatus.completed.name;
    
    await _database.ref().update(updates);

    await _cleanupScheduledNotifications(appointmentId);

    // ADD THIS LINE TO SEND THE NOTIFICATION
    await _sendNotificationToStudent(studentNumber, TeacherAction.meetNow, null);
    
    return true;
  } catch (e) {
    debugPrint('Error completing appointment: $e');
    return false;
  }
}

  Stream<bool> hasPendingAppointmentStream({
    required String studentNumber,
    required String teacherUid,
  }) {
    try {
    return _database
        .ref('appointments/$studentNumber')
        .orderByChild('teacherUid')
        .equalTo(teacherUid)
        .onValue // Use .onValue to create a real-time stream
        .map((event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        for (var entry in data.values) {
            final appointment = Map<String, dynamic>.from(entry as Map);
            if (appointment['status'] == AppointmentStatus.pending.name) {
            return true; // A pending appointment exists
            }
        }
        }
        return false; // No pending appointments found
    });
    } catch (e) {
    debugPrint('Error checking pending appointment stream: $e');
    return Stream.value(false); // On error, return a stream of 'false'
    }
}

// Future<bool> sendTestNotificationToStudent(String studentNumber) async {
//   try {
//     debugPrint('🧪 TEST: Attempting to send test notification to student $studentNumber');
    
//     // Get student UID
//     final studentSnapshot = await _database
//         .ref('users')
//         .orderByChild('studentNumber')
//         .equalTo(studentNumber)
//         .limitToFirst(1)
//         .get();
    
//     if (!studentSnapshot.exists) {
//       debugPrint('❌ TEST: Student not found');
//       return false;
//     }
    
//     final studentData = Map<String, dynamic>.from(
//       (studentSnapshot.value as Map).values.first
//     );
//     final studentUid = studentData['uid'] as String;
//     debugPrint('✅ TEST: Found student UID: $studentUid');
    
//     // Get tokens
//     final tokensSnapshot = await _database.ref('fcm_tokens/$studentUid').get();
//     if (!tokensSnapshot.exists) {
//       debugPrint('❌ TEST: No FCM tokens found for student');
//       return false;
//     }
    
//     final tokensData = Map<String, dynamic>.from(tokensSnapshot.value as Map);
//     debugPrint('✅ TEST: Found ${tokensData.length} device token(s)');
    
//     // Send test notification to all devices
//     int successCount = 0;
//     for (var tokenEntry in tokensData.entries) {
//       final tokenInfo = Map<String, dynamic>.from(tokenEntry.value as Map);
//       final token = tokenInfo['token'] as String?;
      
//       if (token != null) {
//         await _database.ref('notification_queue').push().set({
//           'to': token,
//           'notification': {
//             'title': '🧪 Test Notification',
//             'body': 'This is a test notification from KnockSense. If you see this, notifications are working!',
//           },
//           'data': {
//             'type': 'test_notification',
//             'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
//           },
//           'priority': 'high',
//           'createdAt': ServerValue.timestamp,
//         });
//         successCount++;
//         debugPrint('✅ TEST: Queued notification for device ${tokenEntry.key}');
//       }
//     }
    
//     debugPrint('✅ TEST: Successfully queued $successCount notification(s)');
//     return successCount > 0;
    
//   } catch (e) {
//     debugPrint('❌ TEST: Error - $e');
//     return false;
//   }
// }

/// Verify student has valid FCM tokens
Future<Map<String, dynamic>> checkStudentNotificationStatus(String studentNumber) async {
  try {
    final result = {
      'studentFound': false,
      'studentUid': null,
      'hasTokens': false,
      'tokenCount': 0,
      'tokenPreviews': <String>[],
    };
    
    // Find student
    final studentSnapshot = await _database
        .ref('users')
        .orderByChild('studentNumber')
        .equalTo(studentNumber)
        .limitToFirst(1)
        .get();
    
    if (!studentSnapshot.exists) {
      debugPrint('❌ Student not found: $studentNumber');
      return result;
    }
    
    result['studentFound'] = true;
    final studentData = Map<String, dynamic>.from(
      (studentSnapshot.value as Map).values.first
    );
    final studentUid = studentData['uid'] as String;
    result['studentUid'] = studentUid;
    
    debugPrint('✅ Found student UID: $studentUid');
    
    // Check tokens
    final tokensSnapshot = await _database.ref('fcm_tokens/$studentUid').get();
    if (!tokensSnapshot.exists) {
      debugPrint('❌ No FCM tokens found for student');
      return result;
    }
    
    result['hasTokens'] = true;
    final tokensData = Map<String, dynamic>.from(tokensSnapshot.value as Map);
    result['tokenCount'] = tokensData.length;
    
    // Extract token strings for debugging (safely)
    final tokenList = <String>[];
    for (var entry in tokensData.values) {
      if (entry is Map) {
        final tokenInfo = Map<String, dynamic>.from(entry);
        final token = tokenInfo['token']?.toString() ?? '';
        if (token.isNotEmpty) {
          // Safe substring with length check
          final preview = token.length > 20 
              ? '${token.substring(0, 20)}...' 
              : token;
          tokenList.add(preview);
        }
      }
    }
    result['tokenPreviews'] = tokenList;
    
    debugPrint('✅ Found ${result['tokenCount']} token(s) for student');
    return result;
    
  } catch (e) {
    debugPrint('❌ Error checking notification status: $e');
    return {'error': e.toString()};
  }
}

/// Check notification queue for pending notifications
Future<void> inspectNotificationQueue() async {
  try {
    final queueSnapshot = await _database.ref('notification_queue').get();
    
    if (!queueSnapshot.exists || queueSnapshot.value == null) {
      debugPrint('📭 Notification queue is empty');
      return;
    }
    
    final queue = Map<String, dynamic>.from(queueSnapshot.value as Map);
    debugPrint('📬 Notification queue has ${queue.length} pending item(s)');
    
    int index = 0;
    for (var entry in queue.entries) {
      index++;
      final item = Map<String, dynamic>.from(entry.value as Map);
      debugPrint('  [$index] ID: ${entry.key}');
      debugPrint('      Type: ${item['data']?['type'] ?? 'unknown'}');
      debugPrint('      To: ${item['to']?.toString().substring(0, 20)}...');
      debugPrint('      Title: ${item['notification']?['title'] ?? item['title'] ?? 'N/A'}');
    }
    
  } catch (e) {
    debugPrint('❌ Error inspecting queue: $e');
  }
}


  

  Future<void> _sendScheduledNotificationToTeacher(
  String teacherUid, 
  String studentName, 
  DateTime scheduledTime,
) async {
  try {
    final timeString = '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';
    final dateString = '${scheduledTime.month}/${scheduledTime.day}/${scheduledTime.year}';
    final cleanStudentName = studentName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

    final String body = '$cleanStudentName scheduled an appointment for $timeString on $dateString';

    await _database.ref('notification_queue').push().set({
      'teacherUid': teacherUid,
      'notification': {
        'title': '📅 New Scheduled Appointment',
        'body': body,
      },
      'data': {
        'type': 'scheduled_appointment_request',
        'teacherUid': teacherUid,
        'studentName': cleanStudentName,
        'scheduledTime': scheduledTime.millisecondsSinceEpoch.toString(),
        'bigText': body,
      },
      'priority': 'high',
      'createdAt': ServerValue.timestamp,
    });

    debugPrint('Scheduled appointment notification sent to teacher $teacherUid');
  } catch (e) {
    debugPrint('Error sending scheduled notification to teacher: $e');
  }
}

Future<void> _sendImmediateAppointmentNotificationToTeacher(
  String teacherUid, 
  String studentName,
  {bool isSpecial = false}
) async {
  try {
    
    // Get teacher's FCM tokens
    final tokensSnapshot = await _database.ref('fcm_tokens/$teacherUid').get();
    
    if (!tokensSnapshot.exists) {
      debugPrint('❌ No FCM tokens found for teacher $teacherUid');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return;
    }
    
    final tokensData = Map<String, dynamic>.from(tokensSnapshot.value as Map);
    
    
    // Clean student name
    final cleanStudentName = studentName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    // Send notification to each device token
    
    for (var tokenEntry in tokensData.values) {
      final tokenData = Map<String, dynamic>.from(tokenEntry as Map);
      final token = tokenData['token'] as String?;
      
      if (token != null) {
        await _database.ref('notification_queue').push().set({
          'to': token,
          'notification': {
            'title': '🔔 New Appointment Request',
            'body': '$cleanStudentName would like to meet with you now.',
          },
          'data': {
            'type': 'immediate_appointment_request',
            'studentName': cleanStudentName,
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'isSpecial': isSpecial.toString(),
          },
          'priority': 'high',
          'createdAt': ServerValue.timestamp,
        });
        
      }
    }
    
  } catch (e, stackTrace) {
    debugPrint('❌ Error sending immediate appointment notification to teacher: $e');
    debugPrint('Stack trace: $stackTrace');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}

  Future<void> _sendScheduledAppointmentResponse(
  String studentNumber,
  bool accepted,
  String message,
) async {
  debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  debugPrint('📨 NOTIFICATION: _sendScheduledAppointmentResponse');
  debugPrint('   Student Number: $studentNumber');
  debugPrint('   Accepted: $accepted');
  debugPrint('   Message: $message');

  try {
    final studentSnapshot = await _database
        .ref('roles/student')
        .orderByChild('studentNumber')
        .equalTo(studentNumber)
        .limitToFirst(1)
        .get();

    if (studentSnapshot.exists && studentSnapshot.value != null) {
      final studentMap = studentSnapshot.value as Map;
      final studentUid = studentMap.keys.first;

      // Get teacher name from recent appointment
      String teacherName = 'Your professor';
      try {
        final appointmentSnapshot = await _database
            .ref('appointments/$studentNumber')
            .orderByChild('createdAt')
            .limitToLast(1)
            .get();
        
        if (appointmentSnapshot.exists) {
          final appointmentData = Map<String, dynamic>.from(
            (appointmentSnapshot.value as Map).values.first
          );
          teacherName = appointmentData['teacherName'] ?? 'Your professor';
          teacherName = teacherName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
        }
      } catch (e) {
        debugPrint('Could not fetch teacher name: $e');
      }

      String title;
      String shortBody;
      String longBody;

      if (accepted) {
        title = '✅ $teacherName Accepted Your Appointment';
        shortBody = 'Appointment Accepted';
        longBody = 'Your professor is ready to meet!\n\nYour Professor Location: $message';
      } else {
        title = '❌ $teacherName Declined Your Appointment';
        shortBody = 'Appointment Declined';
        longBody = 'Your scheduled appointment was not accepted.\n\nReason: $message';
      }

      final Map<String, dynamic> dataPayload = {
          'type': 'scheduled_appointment_response',
          'accepted': accepted.toString(),
          'studentNumber': studentNumber,
          'teacherName': teacherName,
          'message': message,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'bigText': longBody,
      };

      await _database.ref('notification_queue').push().set({
        'studentUid': studentUid,
        'notification': {
          'title': title,
          'body': shortBody,
        },
        'data': dataPayload,
        'priority': 'high',
        'createdAt': ServerValue.timestamp,
      });
      debugPrint('✅ Scheduled appointment notification queued for student UID: $studentUid');
    } else {
      debugPrint('⚠️ Student not found with studentNumber: $studentNumber');
    }
  } catch (e) {
    debugPrint('❌ Error sending scheduled appointment response: $e');
  }
}

  // Auto-rejection notification
  Future<void> _sendAutoRejectionNotification(
  String studentNumber,
  String message,
  String teacherName, // ✅ FIX: Accept teacher name as parameter
) async {
  try {
    debugPrint('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓');
    debugPrint('🔔 AUTO-REJECTION NOTIFICATION');
    debugPrint('   Student Number: $studentNumber');
    debugPrint('   Teacher Name: $teacherName'); // ✅ Now uses passed parameter
    
    final studentSnapshot = await _database
        .ref('roles/student')
        .orderByChild('studentNumber')
        .equalTo(studentNumber)
        .limitToFirst(1)
        .get();
    
    if (!studentSnapshot.exists || studentSnapshot.value == null) {
      debugPrint('⚠️ Student not found in roles/student with studentNumber: $studentNumber');
      debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
      return;
    }
    
    final studentMap = studentSnapshot.value as Map;
    final studentUid = studentMap.keys.first;
    
    debugPrint('✅ Found student UID: $studentUid');
    
    final cleanTeacherName = teacherName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

    final String shortBody = 'Appointment Expired';
    final String longBody = '$cleanTeacherName did not respond to your scheduled appointment.\n\n$message';
    
    await _database.ref('notification_queue').push().set({
      'studentUid': studentUid,
      'notification': {
        'title': '⏰ Scheduled Appointment Expired',
        'body': shortBody,
      },
      'data': {
        'type': 'appointment_auto_rejected',
        'studentNumber': studentNumber,
        'teacherName': cleanTeacherName,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'bigText': longBody,
      },
      'priority': 'high',
      'createdAt': ServerValue.timestamp,
    });

    debugPrint('✅ Auto-rejection notification queued for student $studentUid');
    debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
  } catch (e, stackTrace) {
    debugPrint('❌ Error sending auto-rejection notification: $e');
    debugPrint('Stack trace: $stackTrace');
    debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
  }
}

  void dispose() {
  _appointmentMonitorSubscription?.cancel();
  _monitoredAppointments.clear();
}

  Future<void> _sendNotificationToStudent(
  String studentNumber,
  TeacherAction action,
  String? message,
) async {
  try {
    final studentSnapshot = await _database
        .ref('roles/student') 
        .orderByChild('studentNumber')
        .equalTo(studentNumber)
        .limitToFirst(1)
        .get();

    if (studentSnapshot.exists && studentSnapshot.value != null) {
      final studentMap = studentSnapshot.value as Map;
      final studentUid = studentMap.keys.first;

      // Get teacher name from the appointment
      String teacherName = 'Your professor';
      try {
        // Try to get teacher name from the appointment context
        final appointmentSnapshot = await _database
            .ref('appointments/$studentNumber')
            .orderByChild('createdAt')
            .limitToLast(1)
            .get();
        
        if (appointmentSnapshot.exists) {
          final appointmentData = Map<String, dynamic>.from(
            (appointmentSnapshot.value as Map).values.first
          );
          teacherName = appointmentData['teacherName'] ?? 'Your professor';
          // Clean the name (remove parentheses content)
          teacherName = teacherName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
        }
      } catch (e) {
        debugPrint('Could not fetch teacher name: $e');
      }

      String title = _getNotificationTitle(action, teacherName);
      String shortBody = _getNotificationBody(action, null, teacherName); // Get base message without note
      String longBody = _getNotificationBody(action, message, teacherName); // Get full message with note

      final Map<String, dynamic> dataPayload = {
          'type': 'appointment_response',
          'action': action.name,
          'studentNumber': studentNumber,
          'teacherName': teacherName,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      };

      if (message != null && message.isNotEmpty) {
        dataPayload['bigText'] = longBody;
      }

      await _database.ref('notification_queue').push().set({
        'studentUid': studentUid,
        'notification': {
          'title': title,
          'body': shortBody,
        },
        'data': dataPayload,
        'priority': 'high',
        'createdAt': ServerValue.timestamp,
      });
      debugPrint('✅ Notification queued for student UID: $studentUid (action: ${action.name})');
    } else {
      debugPrint('⚠️ Student not found in roles/student with studentNumber: $studentNumber');
    }
  } catch (e) {
    debugPrint('❌ Error sending notification to student: $e');
  }
}

// 2. NEW: Helper method to get notification title
String _getNotificationTitle(TeacherAction action, String teacherName) {
  switch (action) {
    case TeacherAction.meetNow:
      return '✅ Meeting Ready';
    case TeacherAction.wait5Minutes:
      return '⏳ Please Wait';
    case TeacherAction.meetLater:
      return '📅 Meeting Scheduled';
    case TeacherAction.reject:
      return '❌ Appointment Declined';
    default:
      return 'Appointment Update';
  }
}

// 3. UPDATE: Make notification body more descriptive
String _getNotificationBody(TeacherAction action, String? message, String teacherName) {
  String baseMessage;
  
  switch (action) {
    case TeacherAction.meetNow:
      baseMessage = '$teacherName is ready to meet you now!';
      break;
    case TeacherAction.wait5Minutes:
      baseMessage = '$teacherName asks you to wait 5 minutes before coming.';
      break;
    case TeacherAction.meetLater:
      baseMessage = '$teacherName has scheduled your appointment for later.';
      break;
    case TeacherAction.reject:
      baseMessage = '$teacherName declined your appointment request.';
      break;
    default:
      baseMessage = '$teacherName has updated your appointment.';
  }
  
  if (message != null && message.isNotEmpty) {
    baseMessage += '\n\nNote: $message';
  }
  
  return baseMessage;
}



Future<void> _sendCancellationNotification(
  String studentNumber,
  String teacherName,
  String reason,
) async {
  try {
    final studentSnapshot = await _database
        .ref('roles/student') 
        .orderByChild('studentNumber')
        .equalTo(studentNumber)
        .limitToFirst(1)
        .get();

    if (studentSnapshot.exists && studentSnapshot.value != null) {
      final studentMap = studentSnapshot.value as Map;
      final studentUid = studentMap.keys.first;

      // Clean teacher name
      final cleanTeacherName = teacherName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

      String title = '🚫 Meeting Cancelled';
      String shortBody = 'Appointment Cancelled';
      String longBody = '$cleanTeacherName has cancelled your appointment.';
      
      if (reason.isNotEmpty) {
        longBody += '\n\nReason: $reason';
      }

      final Map<String, dynamic> dataPayload = {
          'type': 'appointment_cancelled',
          'studentNumber': studentNumber,
          'teacherName': cleanTeacherName,
          'reason': reason,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      };

      if (reason.isNotEmpty) {
        dataPayload['bigText'] = longBody;
      }

      await _database.ref('notification_queue').push().set({
        'studentUid': studentUid,
        'notification': {
          'title': title,
          'body': shortBody,
        },
        'data': dataPayload,
        'priority': 'high',
        'createdAt': ServerValue.timestamp,
      });
      debugPrint('✅ Cancellation notification queued for student UID: $studentUid');
    }
  } catch (e) {
    debugPrint('❌ Error sending cancellation notification: $e');
  }
}

  Future<void> _scheduleWaitReminder(
  String studentNumber,
  String appointmentId,
  int minutes,
  String teacherUid,
) async {
  try {
    final studentSnapshot = await _database
        .ref('roles/student')
        .orderByChild('studentNumber')
        .equalTo(studentNumber)
        .limitToFirst(1)
        .get();
    
    if (studentSnapshot.exists && studentSnapshot.value != null) {
      final studentMap = studentSnapshot.value as Map;
      final studentUid = studentMap.keys.first;
      final studentData = Map<String, dynamic>.from(studentMap.values.first);
      final studentName = (studentData['displayName'] as String?) ?? studentNumber;
      
      final waitEndTime = DateTime.now().add(Duration(minutes: minutes));
    
      // =============================================================
      // STUDENT: Notification at 5 minutes (wait is over)
      // =============================================================
      final String studentWaitOverBody = 'Your $minutes minute wait is over. You can now proceed to your appointment.';
      await _database.ref('scheduled_notifications').push().set({
        'studentUid': studentUid,
        'studentNumber': studentNumber,
        'appointmentId': appointmentId,
        'type': 'wait_reminder',
        'scheduledFor': waitEndTime.millisecondsSinceEpoch,
        'title': '✅ Wait Period Over',
        'body': studentWaitOverBody,
        'data': {
          'type': 'wait_reminder',
          'appointmentId': appointmentId,
          'bigText': studentWaitOverBody,
        },
        'createdAt': ServerValue.timestamp,
      });

      // =============================================================
      // TEACHER: Notification at 5 minutes (decision window starts)
      // =============================================================
      final String teacherDecisionBody = '$studentName\'s $minutes minute wait has ended. You have 2 minutes to accept or cancel the meeting.';
      await _database.ref('scheduled_notifications').push().set({
        'teacherUid': teacherUid,
        'appointmentId': appointmentId,
        'studentNumber': studentNumber,
        'type': 'wait_decision_window',
        'scheduledFor': waitEndTime.millisecondsSinceEpoch,
        'title': '⏰ Decision Required',
        'body': teacherDecisionBody,
        'data': {
          'type': 'wait_decision_window',
          'appointmentId': appointmentId,
          'studentNumber': studentNumber,
          'bigText': teacherDecisionBody,
        },
        'createdAt': ServerValue.timestamp,
      });
      
      // =============================================================
      // TEACHER: Warning notification at 6 minutes (1 minute left)
      // =============================================================
      final String teacherWarningBody = 'You have 1 minute left to respond to $studentName\'s appointment or it will be auto-cancelled.';
      await _database.ref('scheduled_notifications').push().set({
        'teacherUid': teacherUid,
        'appointmentId': appointmentId,
        'studentNumber': studentNumber,
        'type': 'wait_decision_warning',
        'scheduledFor': waitEndTime.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
        'title': '⚠️ 1 Minute Remaining',
        'body': teacherWarningBody,
        'data': {
          'type': 'wait_decision_warning',
          'appointmentId': appointmentId,
          'studentNumber': studentNumber,
          'bigText': teacherWarningBody,
        },
        
        'createdAt': ServerValue.timestamp,
      });
      
      debugPrint('⏰ Wait reminders scheduled for student $studentNumber in $minutes minutes');
    } else {
      debugPrint('⚠️ Student not found in roles/student for wait reminder: $studentNumber');
    }
  } catch (e) {
    debugPrint('Error scheduling wait reminder: $e');
  }
}

// Future<void> _sendScheduledAppointmentDueNotification(
//   String teacherUid,
//   String studentName,
//   String appointmentId,
// ) async {
//   try {
//     debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//     debugPrint('⏰ SCHEDULED APPOINTMENT DUE NOTIFICATION');
//     debugPrint('   Teacher UID: $teacherUid');
//     debugPrint('   Student Name: $studentName');
//     debugPrint('   Appointment ID: $appointmentId');

//     final cleanStudentName = studentName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

//     await _database.ref('notification_queue').push().set({
//       'teacherUid': teacherUid,
//       'notification': {
//         'title': '⏰ Scheduled Appointment Ready',
//         'body': '$cleanStudentName\'s appointment time has arrived. You have 2 minutes to respond or it will be auto-cancelled.',
//       },
//       'data': {
//         'type': 'scheduled_appointment_due',
//         'studentName': cleanStudentName,
//         'appointmentId': appointmentId,
//         'urgency': 'high',
//         'click_action': 'FLUTTER_NOTIFICATION_CLICK',
//       },
//       'priority': 'high',
//       'createdAt': ServerValue.timestamp,
//     });

//     debugPrint('✅ Scheduled due notification queued for teacher $teacherUid');
//     debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//   } catch (e, stackTrace) {
//     debugPrint('❌ Error sending scheduled appointment due notification: $e');
//     debugPrint('Stack trace: $stackTrace');
//     debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//   }
// }

Future<void> _sendScheduledAppointmentReminder(
  String teacherUid,
  String studentName,
  DateTime scheduledTime,
  String appointmentId,
  String studentNumber,
) async {
  try {
    // Schedule a reminder 4 minutes before the appointment.
    DateTime reminderTime = scheduledTime.subtract(const Duration(minutes: 4));
    if (reminderTime.isBefore(DateTime.now())) {
      // If the reminder time has already passed, schedule it a few seconds from now.
      reminderTime = DateTime.now().add(const Duration(seconds: 10));
    }

    final cleanStudentName = studentName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    final timeString = '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';

    final String body = 'Reminder: Appointment with $cleanStudentName at $timeString';

    final reminderKey = 'reminder_$appointmentId';
    await _database.ref('scheduled_notifications/$reminderKey').set({
      'notificationId': reminderKey,
      'teacherUid': teacherUid,
      'appointmentId': appointmentId,
      'studentNumber': studentNumber,
      'type': 'scheduled_appointment_reminder',
      'scheduledFor': reminderTime.millisecondsSinceEpoch,
      'title': '📅 Upcoming Appointment',
      'body': body,
      'data': {
        'type': 'scheduled_appointment_reminder',
        'studentName': cleanStudentName,
        'appointmentId': appointmentId,
        'bigText': body,
      },
      'createdAt': ServerValue.timestamp,
    });
    debugPrint('⏰ Scheduled reminder for appointment with $cleanStudentName');

  } catch (e) {
    debugPrint('Error scheduling appointment reminder: $e');
  }
}

  Future<bool> meetAndCompleteAppointment({
  required String studentNumber,
  required String appointmentId,
  required String teacherUid,
  String? teacherNote,
}) async {
  try {
    final updates = <String, dynamic>{};
    
    // Directly mark as completed
    updates['appointments/$studentNumber/$appointmentId/status'] = 
        AppointmentStatus.completed.name;
    updates['appointments/$studentNumber/$appointmentId/completedAt'] = 
        ServerValue.timestamp;
    updates['appointments/$studentNumber/$appointmentId/teacherAction'] = 
        TeacherAction.meetNow.name;
    
    if (teacherNote != null) {
      updates['appointments/$studentNumber/$appointmentId/teacherResponse'] = teacherNote;
    }
    
    updates['teacher_appointments/$teacherUid/$appointmentId/status'] = 
        AppointmentStatus.completed.name;
    updates['teacher_appointments/$teacherUid/$appointmentId/completedAt'] = 
        ServerValue.timestamp;
    
    await _database.ref().update(updates);

    await _cleanupScheduledNotifications(appointmentId);
    
    // Send notification to student that meeting is complete
    await _sendNotificationToStudent(
      studentNumber, 
      TeacherAction.meetNow,
      'Meeting completed',
    );
    
    return true;
  } catch (e) {
    debugPrint('Error completing appointment: $e');
    return false;
  }
}
}