import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knocksense/models/appointment_model.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/models/teacher_model.dart';

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
    
    // Get the last reset time (6:30 AM today or yesterday)
    DateTime lastReset = DateTime(now.year, now.month, now.day, 6, 30);
    if (now.isBefore(lastReset)) {
      // If it's before 6:30 AM today, the last reset was yesterday
      lastReset = lastReset.subtract(const Duration(days: 1));
    }
    
    // Get all teacher appointments
    final snapshot = await _database.ref('teacher_appointments').get();
    if (!snapshot.exists || snapshot.value == null) return;
    
    final teacherData = Map<String, dynamic>.from(snapshot.value as Map);
    
    for (var teacherEntry in teacherData.entries) {
      final teacherUid = teacherEntry.key;
      final appointments = Map<String, dynamic>.from(teacherEntry.value as Map);
      
      for (var appointmentEntry in appointments.entries) {
        final appointmentId = appointmentEntry.key;
        final indexData = Map<String, dynamic>.from(appointmentEntry.value as Map);
        
        // Get the full appointment details
        final studentNumber = indexData['studentNumber'] as String;
        final appointmentSnapshot = await _database
            .ref('appointments/$studentNumber/$appointmentId')
            .get();
            
        if (!appointmentSnapshot.exists) continue;
        
        final appointmentData = Map<String, dynamic>.from(
          appointmentSnapshot.value as Map
        );
        
        // Check if appointment should be auto-cancelled
        if (_shouldAutoCancelAppointment(appointmentData, lastReset, now)) {
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
    // This appointment is from before the reset and hasn't been touched
    
    // Additional check: Only cancel if it's NOT a scheduled appointment for the future
    final isScheduled = appointmentData['isScheduled'] ?? false;
    final scheduledTime = appointmentData['scheduledTime'];
    
    if (isScheduled && scheduledTime != null) {
      final scheduledDateTime = DateTime.fromMillisecondsSinceEpoch(scheduledTime as int);
      // Don't cancel if the scheduled time is still in the future
      if (scheduledDateTime.isAfter(now)) {
        return false;
      }
    }
    
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
      });

      // Send notification based on appointment type
      if (isScheduled && scheduledTime != null) {
        await _sendScheduledNotificationToTeacher(teacher.uid, student.displayName, scheduledTime);
        await _sendScheduledAppointmentReminder(teacher.uid, student.displayName, scheduledTime);
      } else {
        // ADD THIS ELSE BLOCK
        // This is an immediate request, so notify the teacher
        await _sendImmediateAppointmentNotificationToTeacher(teacher.uid, student.displayName);
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
      final uniqueKey = '$teacherUid-$appointmentId';
      
      // Skip if already monitoring this appointment
      if (_monitoredAppointments.contains(uniqueKey)) continue;
      
      final indexData = Map<String, dynamic>.from(appointmentEntry.value as Map);
      
      if (indexData['isScheduled'] == true && 
          indexData['scheduledTime'] != null &&
          indexData['status'] == AppointmentStatus.pending.name) {
        
        final scheduledTime = DateTime.fromMillisecondsSinceEpoch(
          indexData['scheduledTime'] as int
        );
        
        // Calculate delay until auto-rejection (2 minutes after scheduled time)
        final autoRejectTime = scheduledTime.add(const Duration(minutes: 2));
        final delay = autoRejectTime.difference(now);
        
        if (delay.isNegative) {
          // Already past the time, reject immediately
          await _autoRejectAppointment(
            studentNumber: indexData['studentNumber'] as String,
            appointmentId: appointmentId,
            teacherUid: teacherUid,
            reason: "The professor hasn't been able to accept or deny the scheduled meeting request.",
          );
          _monitoredAppointments.add(uniqueKey);
        } else {
          // Schedule future rejection
          _monitoredAppointments.add(uniqueKey);
          Timer(delay, () async {
            // Check if still pending before auto-rejecting
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
              }
            }
            _monitoredAppointments.remove(uniqueKey);
          });
        }
      }
    }
  }
}

  Future<void> _autoRejectAppointment({
  required String studentNumber,
  required String appointmentId,
  required String teacherUid,
  required String reason,
}) async {
  try {
    // First check if appointment still exists and is pending
    final appointmentSnapshot = await _database
        .ref('appointments/$studentNumber/$appointmentId')
        .get();
    
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
    
    // Use a unique timestamp to force stream updates
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Update main appointment
    updates['appointments/$studentNumber/$appointmentId/status'] = 
        AppointmentStatus.cancelled.name;
    updates['appointments/$studentNumber/$appointmentId/autoRejected'] = true;
    updates['appointments/$studentNumber/$appointmentId/autoRejectedAt'] = timestamp;
    updates['appointments/$studentNumber/$appointmentId/teacherResponse'] = reason;
    updates['appointments/$studentNumber/$appointmentId/lastModified'] = timestamp;
    
    // Update teacher's copy
    updates['teacher_appointments/$teacherUid/$appointmentId/status'] = 
        AppointmentStatus.cancelled.name;
    updates['teacher_appointments/$teacherUid/$appointmentId/autoRejected'] = true;
    updates['teacher_appointments/$teacherUid/$appointmentId/lastModified'] = timestamp;
    updates['teacher_appointments/$teacherUid/$appointmentId/autoRejectedAt'] = timestamp;
    
    // Perform atomic update
    await _database.ref().update(updates);
    
    // Send notification to student
    await _sendAutoRejectionNotification(studentNumber, reason);
    
    // Clean up from monitored set
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
    final List<AppointmentModel> filteredAppointments = [];

    for (var appointment in appointments) {
      // Skip cancelled, denied, AND completed appointments
      if (appointment.status == AppointmentStatus.cancelled ||
          appointment.status == AppointmentStatus.denied ||
          appointment.status == AppointmentStatus.completed) {
        continue;
      }
      
      bool shouldInclude = false;

      // Check if it's a scheduled appointment for today
      if (appointment.scheduledTime != null) {
        final scheduledDate = appointment.scheduledTime!;
        
        // Check if appointment is for today
        final isToday = scheduledDate.year == now.year &&
                       scheduledDate.month == now.month &&
                       scheduledDate.day == now.day;
        
        if (isToday) {
          // Check if scheduled appointment has expired
          final expirationTime = scheduledDate.add(const Duration(minutes: 2));
          
          // Check for auto-rejection conditions
          if (now.isAfter(expirationTime) && 
              appointment.status == AppointmentStatus.pending) {
            // This appointment should be auto-rejected, skip it
            debugPrint('Skipping expired pending appointment ${appointment.appointmentId}');
            
            // Trigger auto-rejection if not already done
            final uniqueKey = '$teacherUid-${appointment.appointmentId}';
            if (!_monitoredAppointments.contains(uniqueKey)) {
              _monitoredAppointments.add(uniqueKey);
              // Schedule immediate auto-rejection
              Future.microtask(() => _autoRejectAppointment(
                studentNumber: appointment.studentNumber,
                appointmentId: appointment.appointmentId,
                teacherUid: teacherUid,
                reason: "The professor hasn't been able to accept or deny the scheduled meeting request.",
              ));
            }
            continue; // Skip this appointment
          }
          
          // Include if not expired OR already accepted/in progress
          if (now.isBefore(expirationTime) || 
              appointment.status == AppointmentStatus.accepted) {
            shouldInclude = true;
          }
        }
      } 
      // Also include immediate appointments created today
      else if (appointment.isToday && !appointment.isScheduled) {
        shouldInclude = true;
      }
      
      if (shouldInclude) {
        filteredAppointments.add(appointment);
      }
    }

    // Sort by priority
    filteredAppointments.sort((a, b) {
      // Pending appointments come before accepted
      if (a.status == AppointmentStatus.pending && 
          b.status != AppointmentStatus.pending) return -1;
      if (a.status != AppointmentStatus.pending && 
          b.status == AppointmentStatus.pending) return 1;
      
      // Near scheduled appointments come first
      if (a.isNear && !b.isNear) return -1;
      if (!a.isNear && b.isNear) return 1;
      
      // Scheduled appointments come before immediate ones
      if (a.isScheduled && !b.isScheduled) return -1;
      if (!a.isScheduled && b.isScheduled) return 1;
      
      // Finally sort by time
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
            
            // Filter for future appointments
            if (appointment.isFuture && 
              appointment.status == AppointmentStatus.pending) {  // Only show pending future appointments
              appointments.add(appointment);
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

        print('🔧 SERVICE: Updating database...');
        print('   Updates: ${updates.keys.toList()}');

        print('✅ SERVICE: Database updated successfully');
        print('🔧 SERVICE: Now sending notification...');
      
      // Send notification with the teacher's response/location
      await _sendScheduledAppointmentResponse(studentNumber, accept, teacherResponse);

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

      if (action == TeacherAction.wait5Minutes) {
        await _scheduleWaitReminder(studentNumber, appointmentId, 5, teacherUid);
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

    // Send descriptive cancellation notification
    await _sendCancellationNotification(
      studentNumber,
      teacherName,
      reason ?? 'No reason provided.',
    );

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

Future<bool> sendTestNotificationToStudent(String studentNumber) async {
  try {
    debugPrint('🧪 TEST: Attempting to send test notification to student $studentNumber');
    
    // Get student UID
    final studentSnapshot = await _database
        .ref('users')
        .orderByChild('studentNumber')
        .equalTo(studentNumber)
        .limitToFirst(1)
        .get();
    
    if (!studentSnapshot.exists) {
      debugPrint('❌ TEST: Student not found');
      return false;
    }
    
    final studentData = Map<String, dynamic>.from(
      (studentSnapshot.value as Map).values.first
    );
    final studentUid = studentData['uid'] as String;
    debugPrint('✅ TEST: Found student UID: $studentUid');
    
    // Get tokens
    final tokensSnapshot = await _database.ref('fcm_tokens/$studentUid').get();
    if (!tokensSnapshot.exists) {
      debugPrint('❌ TEST: No FCM tokens found for student');
      return false;
    }
    
    final tokensData = Map<String, dynamic>.from(tokensSnapshot.value as Map);
    debugPrint('✅ TEST: Found ${tokensData.length} device token(s)');
    
    // Send test notification to all devices
    int successCount = 0;
    for (var tokenEntry in tokensData.entries) {
      final tokenInfo = Map<String, dynamic>.from(tokenEntry.value as Map);
      final token = tokenInfo['token'] as String?;
      
      if (token != null) {
        await _database.ref('notification_queue').push().set({
          'to': token,
          'notification': {
            'title': '🧪 Test Notification',
            'body': 'This is a test notification from KnockSense. If you see this, notifications are working!',
          },
          'data': {
            'type': 'test_notification',
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          },
          'priority': 'high',
          'createdAt': ServerValue.timestamp,
        });
        successCount++;
        debugPrint('✅ TEST: Queued notification for device ${tokenEntry.key}');
      }
    }
    
    debugPrint('✅ TEST: Successfully queued $successCount notification(s)');
    return successCount > 0;
    
  } catch (e) {
    debugPrint('❌ TEST: Error - $e');
    return false;
  }
}

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
    final tokensSnapshot = await _database.ref('fcm_tokens/$teacherUid').get();
    if (tokensSnapshot.exists) {
      final tokensData = Map<String, dynamic>.from(tokensSnapshot.value as Map);
      
      final timeString = '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';
      final dateString = '${scheduledTime.month}/${scheduledTime.day}/${scheduledTime.year}';
      
      // Clean student name
      final cleanStudentName = studentName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
      
      for (var tokenEntry in tokensData.values) {
        final tokenData = Map<String, dynamic>.from(tokenEntry as Map);
        final token = tokenData['token'] as String?;
        
        if (token != null) {
          await _database.ref('notification_queue').push().set({
            'to': token,
            'notification': {
              'title': '📅 New Scheduled Appointment',
              'body': '$cleanStudentName scheduled an appointment for $timeString on $dateString',
            },
            'data': {
              'type': 'scheduled_appointment_request',
              'teacherUid': teacherUid,
              'studentName': cleanStudentName,
              'scheduledTime': scheduledTime.millisecondsSinceEpoch.toString(),
            },
            'priority': 'high',
            'createdAt': ServerValue.timestamp,
          });
        }
      }
      debugPrint('Scheduled appointment notification sent to teacher $teacherUid');
    }
  } catch (e) {
    debugPrint('Error sending scheduled notification to teacher: $e');
  }
}

Future<void> _sendImmediateAppointmentNotificationToTeacher(
  String teacherUid, 
  String studentName,
) async {
  try {
    // Clean student name
    final cleanStudentName = studentName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    
    await _database.ref('notification_queue').push().set({
      'teacherUid': teacherUid,
      'notification': {
        'title': '🔔 New Appointment Request',
        'body': '$cleanStudentName would like to meet with you now.',
        'channelId': 'appointments',
      },
      'data': {
        'type': 'immediate_appointment_request',
        'studentName': cleanStudentName,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
      'priority': 'high',
      'createdAt': ServerValue.timestamp,
    });
    debugPrint('✅ Immediate appointment notification queued for teacher $teacherUid');
  } catch (e) {
    debugPrint('❌ Error sending immediate appointment notification to teacher: $e');
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
        .ref('users')
        .orderByChild('studentNumber')
        .equalTo(studentNumber)
        .limitToFirst(1)
        .get();

    if (studentSnapshot.exists) {
      final studentData = Map<String, dynamic>.from(
        (studentSnapshot.value as Map).values.first
      );
      final studentUid = studentData['uid'] as String;

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
      String body;

      if (accepted) {
        title = '✅ $teacherName Accepted Your Appointment';
        body = 'Your professor is ready to meet!\n\nLocation: $message';
      } else {
        title = '❌ $teacherName Declined Your Appointment';
        body = 'Your scheduled appointment was not accepted.\n\nReason: $message';
      }

      await _database.ref('notification_queue').push().set({
        'studentUid': studentUid,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          'type': 'scheduled_appointment_response',
          'accepted': accepted.toString(),
          'studentNumber': studentNumber,
          'teacherName': teacherName,
          'message': message,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
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
) async {
  try {
    final studentSnapshot = await _database
        .ref('roles/student')
        .orderByChild('studentNumber')
        .equalTo(studentNumber)
        .limitToFirst(1)
        .get();
    
    if (studentSnapshot.exists) {
      final studentData = Map<String, dynamic>.from(
        (studentSnapshot.value as Map).values.first
      );
      final studentUid = studentData['uid'] as String;
      
      // Try to get teacher name from recent appointment
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
        debugPrint('Could not fetch teacher name for auto-rejection: $e');
      }
      
      final tokensSnapshot = await _database.ref('fcm_tokens/$studentUid').get();
      if (tokensSnapshot.exists) {
        final tokensData = Map<String, dynamic>.from(tokensSnapshot.value as Map);
        
        for (var tokenEntry in tokensData.values) {
          final tokenData = Map<String, dynamic>.from(tokenEntry as Map);
          final token = tokenData['token'] as String?;
          
          if (token != null) {
            await _database.ref('notification_queue').push().set({
              'to': token,
              'notification': {
                'title': '⏰ Scheduled Appointment Expired',
                'body': '$teacherName did not respond to your scheduled appointment.\n\n$message',
              },
              'data': {
                'type': 'appointment_auto_rejected',
                'studentNumber': studentNumber,
                'teacherName': teacherName,
              },
              'priority': 'high',
              'createdAt': ServerValue.timestamp,
            });
          }
        }
        debugPrint('Auto-rejection notification sent to student $studentNumber');
      }
    }
  } catch (e) {
    debugPrint('Error sending auto-rejection notification: $e');
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
      String body = _getNotificationBody(action, message, teacherName);

      await _database.ref('notification_queue').push().set({
        'studentUid': studentUid,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          'type': 'appointment_response',
          'action': action.name,
          'studentNumber': studentNumber,
          'teacherName': teacherName,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
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
      String body = '$cleanTeacherName has cancelled your appointment.';
      
      if (reason.isNotEmpty) {
        body += '\n\nReason: $reason';
      }

      await _database.ref('notification_queue').push().set({
        'studentUid': studentUid,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          'type': 'appointment_cancelled',
          'studentNumber': studentNumber,
          'teacherName': cleanTeacherName,
          'reason': reason,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
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
    // ✅ MODIFIED: The query now targets the 'roles/student' path for better security and efficiency.
    final studentSnapshot = await _database
        .ref('roles/student')
        .orderByChild('studentNumber')
        .equalTo(studentNumber)
        .limitToFirst(1)
        .get();
    
    if (studentSnapshot.exists && studentSnapshot.value != null) {
      // ✅ MODIFIED: Safely extract the UID from the document key and the data from the value.
      // This prevents crashes if the 'uid' field is missing inside the data.
      final studentMap = studentSnapshot.value as Map;
      final studentUid = studentMap.keys.first;
      final studentData = Map<String, dynamic>.from(studentMap.values.first);
      
      // Use the retrieved display name with a fallback to the student number.
      final studentName = (studentData['displayName'] as String?) ?? studentNumber;
      
      final reminderTime = DateTime.now().add(Duration(minutes: minutes));
    
      await _database.ref('scheduled_notifications').push().set({
        'studentUid': studentUid,
        'studentNumber': studentNumber,
        'appointmentId': appointmentId,
        'type': 'wait_reminder',
        'scheduledFor': reminderTime.millisecondsSinceEpoch,
        'title': 'Appointment Reminder',
        'body': 'Your $minutes minute wait is over. You can now proceed to your appointment.',
        'data': {
          'type': 'wait_reminder',
          'appointmentId': appointmentId,
        },
        'createdAt': ServerValue.timestamp,
      });

      // Also notify the teacher when the wait window ends
      await _database.ref('scheduled_notifications').push().set({
        'teacherUid': teacherUid,
        'appointmentId': appointmentId,
        'type': 'wait_reminder_teacher',
        'scheduledFor': reminderTime.millisecondsSinceEpoch,
        'title': 'Wait window ended',
        'body': '$studentName\'s $minutes minute wait has ended.',
        'data': {
          'type': 'wait_reminder_teacher',
          'appointmentId': appointmentId,
          'studentNumber': studentNumber,
        },
        'createdAt': ServerValue.timestamp,
      });
      
      debugPrint('Wait reminder scheduled for student $studentNumber in $minutes minutes');
    } else {
      debugPrint('⚠️ Student not found in roles/student for wait reminder: $studentNumber');
    }
  } catch (e) {
    debugPrint('Error scheduling wait reminder: $e');
  }
}

Future<void> _sendScheduledAppointmentReminder(
  String teacherUid,
  String studentName,
  DateTime scheduledTime,
) async {
  try {
    // Schedule a reminder 10 minutes before appointment
    final reminderTime = scheduledTime.subtract(const Duration(minutes: 4));
    
    if (reminderTime.isAfter(DateTime.now())) {
      await _database.ref('scheduled_notifications').push().set({
        'teacherUid': teacherUid,
        'type': 'scheduled_appointment_reminder',
        'scheduledFor': reminderTime.millisecondsSinceEpoch,
        'title': 'Upcoming Appointment',
        'body': 'Appointment with $studentName in 4 minutes',
        'data': {
          'type': 'appointment_reminder',
        },
        'createdAt': ServerValue.timestamp,
      });
    }
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