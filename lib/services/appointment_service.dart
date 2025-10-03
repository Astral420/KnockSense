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

  AppointmentService({required FirebaseDatabase database})
      : _database = database {
    _startAppointmentMonitoring();
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
    final updates = <String, dynamic>{};
    
    updates['appointments/$studentNumber/$appointmentId/status'] = 
        AppointmentStatus.cancelled.name;
    updates['appointments/$studentNumber/$appointmentId/autoRejected'] = true;
    updates['appointments/$studentNumber/$appointmentId/autoRejectedAt'] = 
        ServerValue.timestamp;
    updates['appointments/$studentNumber/$appointmentId/teacherResponse'] = reason;
    
    updates['teacher_appointments/$teacherUid/$appointmentId/status'] = 
        AppointmentStatus.cancelled.name;
    updates['teacher_appointments/$teacherUid/$appointmentId/autoRejected'] = true;
    
    await _database.ref().update(updates);
    
    // Force a small update to trigger stream refresh (add a timestamp)
    await _database.ref('teacher_appointments/$teacherUid/$appointmentId/lastUpdated')
        .set(ServerValue.timestamp);
    
    // Send notification to student
    await _sendAutoRejectionNotification(studentNumber, reason);
    
    debugPrint('Auto-rejected appointment $appointmentId for student $studentNumber');
  } catch (e) {
    debugPrint('Error auto-rejecting appointment: $e');
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
        if (scheduledDate.year == now.year &&
            scheduledDate.month == now.month &&
            scheduledDate.day == now.day) {
          
          // Check if scheduled appointment has expired
          final expirationTime = scheduledDate.add(const Duration(minutes: 2));
          
          // Only include if:
          // 1. Not expired yet (still within 2 minutes of scheduled time), OR
          // 2. Already accepted (teacher is handling it)
          if (now.isBefore(expirationTime) || 
              appointment.status == AppointmentStatus.accepted) {
            shouldInclude = true;
          }
          // If expired and still pending, it will be auto-rejected, so exclude it
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
      
      // Near appointments come first
      if (a.isNear && !b.isNear) return -1;
      if (!a.isNear && b.isNear) return 1;
      
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
      
      // Send notification with the teacher's response/location
      await _sendScheduledAppointmentResponse(studentNumber, accept, teacherResponse);
      
      return true;
    } catch (e) {
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
        await _scheduleWaitReminder(studentNumber, appointmentId, 5);
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
      final updates = <String, dynamic>{};
      
      updates['appointments/$studentNumber/$appointmentId/status'] = 
          AppointmentStatus.cancelled.name;
      updates['teacher_appointments/$teacherUid/$appointmentId/status'] = 
          AppointmentStatus.cancelled.name;

      if (reason != null && reason.isNotEmpty) {
        updates['appointments/$studentNumber/$appointmentId/teacherResponse'] = reason;
      }
      
      await _database.ref().update(updates);
      
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


  

  Future<void> _sendScheduledNotificationToTeacher(
  String teacherUid, 
  String studentName, 
  DateTime scheduledTime,
) async {
  try {
    // Get ALL tokens for this teacher (supports multiple devices)
    final tokensSnapshot = await _database.ref('fcm_tokens/$teacherUid').get();
    if (tokensSnapshot.exists) {
      final tokensData = Map<String, dynamic>.from(tokensSnapshot.value as Map);
      
      // Format the scheduled time
      final timeString = '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';
      final dateString = '${scheduledTime.month}/${scheduledTime.day}/${scheduledTime.year}';
      
      // Send to all devices
      for (var tokenEntry in tokensData.values) {
        final tokenData = Map<String, dynamic>.from(tokenEntry as Map);
        final token = tokenData['token'] as String?;
        
        if (token != null) {
          await _database.ref('notification_queue').push().set({
            'to': token,
            'title': 'Scheduled Appointment Request',
            'body': '$studentName has scheduled an appointment for $timeString on $dateString',
            'data': {
              'type': 'scheduled_appointment_request',
              'teacherUid': teacherUid,
              'scheduledTime': scheduledTime.millisecondsSinceEpoch.toString(),
            },
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

  Future<void> _sendScheduledAppointmentResponse(
  String studentNumber, 
  bool accepted, 
  String message,
) async {
  try {
    // Get student UID from student number
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
      
      // Get ALL tokens for this student (supports multiple devices)
      final tokensSnapshot = await _database.ref('fcm_tokens/$studentUid').get();
      if (tokensSnapshot.exists) {
        final tokensData = Map<String, dynamic>.from(tokensSnapshot.value as Map);
        
        String title;
        String body;
        
        if (accepted) {
          title = 'Scheduled Appointment Accepted';
          body = 'Your professor is ready to meet! Location: $message';
        } else {
          title = 'Scheduled Appointment Declined';
          body = 'Reason: $message';
        }
        
        // Send to all devices
        for (var tokenEntry in tokensData.values) {
          final tokenData = Map<String, dynamic>.from(tokenEntry as Map);
          final token = tokenData['token'] as String?;
          
          if (token != null) {
            await _database.ref('notification_queue').push().set({
              'to': token,
              'title': title,
              'body': body,
              'data': {
                'type': 'scheduled_appointment_response',
                'accepted': accepted.toString(),
                'studentNumber': studentNumber,
              },
              'createdAt': ServerValue.timestamp,
            });
          }
        }
        debugPrint('Scheduled appointment response sent to student $studentNumber: ${accepted ? "Accepted" : "Declined"}');
      }
    }
  } catch (e) {
    debugPrint('Error sending scheduled appointment response: $e');
  }
}

  // Auto-rejection notification
  Future<void> _sendAutoRejectionNotification(
  String studentNumber,
  String message,
) async {
  try {
    // Get student UID from student number
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
      
      // Get ALL tokens for this student (supports multiple devices)
      final tokensSnapshot = await _database.ref('fcm_tokens/$studentUid').get();
      if (tokensSnapshot.exists) {
        final tokensData = Map<String, dynamic>.from(tokensSnapshot.value as Map);
        
        // Send to all devices
        for (var tokenEntry in tokensData.values) {
          final tokenData = Map<String, dynamic>.from(tokenEntry as Map);
          final token = tokenData['token'] as String?;
          
          if (token != null) {
            await _database.ref('notification_queue').push().set({
              'to': token,
              'title': 'Scheduled Appointment Cancelled',
              'body': message,
              'data': {
                'type': 'appointment_auto_rejected',
                'studentNumber': studentNumber,
              },
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
    // Get student UID from student number
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
      
      // FIXED: Get ALL tokens for this student
      final tokensSnapshot = await _database.ref('fcm_tokens/$studentUid').get();
      if (tokensSnapshot.exists) {
        final tokensData = Map<String, dynamic>.from(tokensSnapshot.value as Map);
        
        String title = 'Appointment Update';
        String body = _getNotificationBody(action, message);
        
        // Send to all devices
        for (var tokenEntry in tokensData.entries) {
          final tokenInfo = Map<String, dynamic>.from(tokenEntry.value as Map);
          final token = tokenInfo['token'] as String?;
          
          if (token != null) {
            await _database.ref('notification_queue').push().set({
              'to': token,
              'notification': {  // IMPORTANT: Add notification object
                'title': title,
                'body': body,
              },
              'data': {
                'type': 'appointment_response',
                'action': action.name,
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              },
              'priority': 'high',  // Add priority for Android
              'createdAt': ServerValue.timestamp,
            });
            debugPrint('Notification queued for student $studentNumber');
          }
        }
      }
    }
  } catch (e) {
    debugPrint('Error sending notification to student: $e');
  }
}

String _getNotificationBody(TeacherAction action, String? message) {
  String baseMessage;
  switch (action) {
    case TeacherAction.meetNow:
      baseMessage = 'Your teacher is ready to meet you now!';
      break;
    case TeacherAction.wait5Minutes:
      baseMessage = 'Please wait 5 minutes before coming.';
      break;
    case TeacherAction.meetLater:
      baseMessage = 'Your appointment has been scheduled for later.';
      break;
    case TeacherAction.reject:
      baseMessage = 'Your appointment request was declined.';
      break;
    default:
      baseMessage = 'Your appointment status has been updated.';
  }
  
  if (message != null && message.isNotEmpty) {
    baseMessage += '\nMessage: $message';
  }
  
  return baseMessage;
}

  Future<void> _scheduleWaitReminder(
  String studentNumber,
  String appointmentId,
  int minutes,
) async {
  try {
    // Get student UID from student number
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
      
      final reminderTime = DateTime.now().add(Duration(minutes: minutes));
    
    await _database.ref('scheduled_notifications').push().set({
      'studentUid': studentUid,
      'studentNumber': studentNumber,
      'appointmentId': appointmentId,
      'type': 'wait_reminder',
      'scheduledFor': reminderTime.millisecondsSinceEpoch, // Use actual time, not ServerValue.timestamp
      'title': 'Appointment Reminder',
      'body': 'Your $minutes minute wait is over. You can now proceed to your appointment.',
      'data': {
        'type': 'wait_reminder',
        'appointmentId': appointmentId,
      },
      'createdAt': ServerValue.timestamp,
    });
      
      debugPrint('Wait reminder scheduled for student $studentNumber in $minutes minutes');
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
    final reminderTime = scheduledTime.subtract(const Duration(minutes: 10));
    
    if (reminderTime.isAfter(DateTime.now())) {
      await _database.ref('scheduled_notifications').push().set({
        'teacherUid': teacherUid,
        'type': 'scheduled_appointment_reminder',
        'scheduledFor': reminderTime.millisecondsSinceEpoch,
        'title': 'Upcoming Appointment',
        'body': 'Appointment with $studentName in 10 minutes',
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