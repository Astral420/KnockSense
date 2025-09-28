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
  Timer? _appointmentMonitorTimer;

  StreamSubscription? _appointmentMonitorSubscription;
  final Set<String> _monitoredAppointments = {};

  AppointmentService({required FirebaseDatabase database}) 
      : _database = database{

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

  Future<int> getActiveAppointmentCount({
    required String studentNumber,
    required String teacherUid,
  }) async {
    try {
      final snapshot = await _database
          .ref('appointments/$studentNumber')
          .orderByChild('teacherUid')
          .equalTo(teacherUid)
          .get();
          
      if (!snapshot.exists || snapshot.value == null) {
        return 0;
      }
      
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      int activeCount = 0;
      
      for (var entry in data.values) {
        final appointment = Map<String, dynamic>.from(entry as Map);
        final status = appointment['status'] as String;
        
        if (status == AppointmentStatus.pending.name || 
            status == AppointmentStatus.accepted.name) {
          activeCount++;
        }
      }
      
      return activeCount;
    } catch (e) {
      debugPrint('Error getting active appointment count: $e');
      return 0;
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

      final activeCount = await getActiveAppointmentCount(
        studentNumber: student.studentNumber!,
        teacherUid: teacher.uid,
      );
      
      if (activeCount >= MAX_APPOINTMENTS_PER_TEACHER) {
        return {
          'success': false,
          'error': 'You have reached the maximum of $MAX_APPOINTMENTS_PER_TEACHER active appointments with this teacher.',
        };
      }

      // Don't check for pending if it's a scheduled appointment
      if (!isScheduled) {
        final hasPending = await hasPendingAppointment(
          studentNumber: student.studentNumber!,
          teacherUid: teacher.uid,
        );
        
        if (hasPending) {
          return {
            'success': false,
            'error': 'You already have a pending appointment with this teacher.',
          };
        }
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
      if (isScheduled) {
        await _sendScheduledNotificationToTeacher(teacher.uid, student.displayName, effectiveScheduledTime!);
      } else {
        await _sendNotificationToTeacher(teacher.uid, student.displayName);
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



  // // Check appointments for auto-transfer and auto-rejection
  // Future<void> _checkAndUpdateAppointments() async {
  //   try {
  //     final now = DateTime.now();
      
  //     // Get all teacher appointments across the system
  //     final snapshot = await _database.ref('teacher_appointments').get();
      
  //     if (!snapshot.exists || snapshot.value == null) return;
      
  //     final teacherData = Map<String, dynamic>.from(snapshot.value as Map);
      
  //     for (var teacherEntry in teacherData.entries) {
  //       final teacherUid = teacherEntry.key;
  //       final appointments = Map<String, dynamic>.from(teacherEntry.value as Map);
        
  //       for (var appointmentEntry in appointments.entries) {
  //         final appointmentId = appointmentEntry.key;
  //         final indexData = Map<String, dynamic>.from(appointmentEntry.value as Map);
  //         final studentNumber = indexData['studentNumber'] as String;
          
  //         // Get full appointment data
  //         final appointmentSnapshot = await _database
  //             .ref('appointments/$studentNumber/$appointmentId')
  //             .get();
              
  //         if (!appointmentSnapshot.exists) continue;
          
  //         final appointmentData = Map<String, dynamic>.from(appointmentSnapshot.value as Map);
          
  //         // Check if this is a scheduled appointment
  //         if (appointmentData['isScheduled'] == true && 
  //             appointmentData['scheduledTime'] != null) {
            
  //           final scheduledTime = DateTime.fromMillisecondsSinceEpoch(
  //             appointmentData['scheduledTime'] as int
  //           );
            
  //           final status = appointmentData['status'] as String;
            
  //           // Auto-reject if more than 2 minutes past scheduled time and still pending
  //           if (status == AppointmentStatus.pending.name) {
  //             final minutesPast = now.difference(scheduledTime).inMinutes;
              
  //             if (minutesPast > 2) {
  //               await _autoRejectAppointment(
  //                 studentNumber: studentNumber,
  //                 appointmentId: appointmentId,
  //                 teacherUid: teacherUid,
  //                 reason: "The professor hasn't been able to accept or deny the scheduled meeting request.",
  //               );
  //             }
  //           }
  //         }
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint('Error in appointment monitoring: $e');
  //   }
  // }

  // Auto-reject appointment
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
      
      // Send notification to student
      await _sendAutoRejectionNotification(studentNumber, reason);
      
      debugPrint('Auto-rejected appointment $appointmentId for student $studentNumber');
    } catch (e) {
      debugPrint('Error auto-rejecting appointment: $e');
    }
  }

  // Get today's appointments for teacher
 Stream<List<AppointmentModel>> getTeacherTodayAppointments(String teacherUid) {
  final ref = _database.ref('teacher_appointments/$teacherUid');

  // Listen for real-time changes at the teacher's appointment index
  return ref.onValue.asyncMap((event) async {
    if (!event.snapshot.exists || event.snapshot.value == null) {
      return []; // Return an empty list if there's no data
    }

    final indexData = Map<String, dynamic>.from(event.snapshot.value as Map);
    final List<Future<AppointmentModel?>> appointmentFutures = [];

    // Create a list of futures to fetch all appointment details in parallel
    for (var entry in indexData.entries) {
      final appointmentIndex = Map<String, dynamic>.from(entry.value as Map);
      final studentNumber = appointmentIndex['studentNumber'] as String;
      final appointmentId = appointmentIndex['appointmentId'] as String;

      appointmentFutures.add(
        _fetchAppointmentDetails(studentNumber, appointmentId),
      );
    }

    // Wait for all futures to complete
    final appointmentsNullable = await Future.wait(appointmentFutures);
    final appointments = appointmentsNullable.whereType<AppointmentModel>().toList();

    // The rest of your filtering and sorting logic...
    final now = DateTime.now();
    final List<AppointmentModel> filteredAppointments = [];

    for (var appointment in appointments) {
    // Skip completed, cancelled, or denied appointments
    if (appointment.status == AppointmentStatus.completed ||
        appointment.status == AppointmentStatus.cancelled ||
        appointment.status == AppointmentStatus.denied) {
        continue; // Skip these appointments entirely
    }
    
    bool shouldInclude = false;

     if (appointment.scheduledTime != null) {
        final scheduledDate = appointment.scheduledTime!;
        if (scheduledDate.year == now.year &&
            scheduledDate.month == now.month &&
            scheduledDate.day == now.day &&
            scheduledDate.isBefore(now.add(const Duration(minutes: 10)))) {
            shouldInclude = true;
        }
    }
        
        // Also include immediate appointments created today
        if (appointment.isToday && !appointment.isScheduled) {
            shouldInclude = true;
        }
        
        // Include active appointments regardless of date check
        if (appointment.status == AppointmentStatus.pending ||
            appointment.status == AppointmentStatus.accepted) {
            if (shouldInclude) {
                filteredAppointments.add(appointment);
            }
        }
    }

    // Sort by priority
    filteredAppointments.sort((a, b) {
      if (a.isNear && !b.isNear) return -1;
      if (!a.isNear && b.isNear) return 1;
      
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
      
      final newStatus = accept ? AppointmentStatus.accepted : AppointmentStatus.denied;
      
      updates['appointments/$studentNumber/$appointmentId/status'] = newStatus.name;
      updates['appointments/$studentNumber/$appointmentId/respondedAt'] = ServerValue.timestamp;
      updates['appointments/$studentNumber/$appointmentId/teacherResponse'] = teacherResponse;
      
      // For scheduled appointments, if accepted, treat as "meet now"
      if (accept) {
        updates['appointments/$studentNumber/$appointmentId/teacherAction'] = TeacherAction.meetNow.name;
        // Mark as completed since it's an immediate meeting
        updates['appointments/$studentNumber/$appointmentId/completedAt'] = ServerValue.timestamp;
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

  Future<bool> hasPendingAppointment({
    required String studentNumber,
    required String teacherUid,
  }) async {
    try {
      final snapshot = await _database
          .ref('appointments/$studentNumber')
          .orderByChild('teacherUid')
          .equalTo(teacherUid)
          .get();
          
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        
        for (var entry in data.values) {
          final appointment = Map<String, dynamic>.from(entry as Map);
          if (appointment['status'] == AppointmentStatus.pending.name) {
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking pending appointment: $e');
      return false;
    }
  }

  // Notification methods
  Future<void> _sendNotificationToTeacher(String teacherUid, String studentName) async {
    debugPrint('Immediate appointment notification sent to teacher: New request from $studentName');
  }

  Future<void> _sendScheduledNotificationToTeacher(String teacherUid, String studentName, DateTime scheduledTime) async {
    debugPrint('Scheduled appointment notification: $studentName scheduled for $scheduledTime');
  }

  Future<void> _sendScheduledAppointmentResponse(
    String studentNumber, 
    bool accepted, 
    String message,
  ) async {
    if (accepted) {
      // Message should contain location information
      debugPrint('Scheduled appointment accepted. Professor location: $message');
    } else {
      // Message contains rejection reason
      debugPrint('Scheduled appointment rejected. Reason: $message');
    }
    // Implement actual notification logic here
  }

  // Auto-rejection notification
  Future<void> _sendAutoRejectionNotification(
    String studentNumber,
    String message,
  ) async {
    debugPrint('Auto-rejection notification sent to student: $message');
    // Implement actual notification logic here
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
    String notificationMessage;
    switch (action) {
      case TeacherAction.meetNow:
        notificationMessage = 'Your teacher is ready to meet you now!';
        break;
      case TeacherAction.wait5Minutes:
        notificationMessage = 'Please wait 5 minutes before coming.';
        break;
      case TeacherAction.meetLater:
        notificationMessage = 'Your appointment has been scheduled for later.';
        break;
      case TeacherAction.reject:
        notificationMessage = 'Your appointment request was declined.';
        break;
      default:
        notificationMessage = 'Your appointment status has been updated.';
    }
    
    if (message != null) {
      notificationMessage += '\nMessage: $message';
    }
    
    debugPrint('Notification sent to student: $notificationMessage');
  }

  Future<void> _scheduleWaitReminder(
    String studentNumber,
    String appointmentId,
    int minutes,
  ) async {
    debugPrint('Reminder scheduled for student $studentNumber in $minutes minutes');
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

