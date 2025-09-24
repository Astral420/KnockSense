import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knocksense/models/appointment_model.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/models/teacher_model.dart';

class AppointmentService {
  final FirebaseDatabase _database;
  static const int MAX_APPOINTMENTS_PER_TEACHER = 3;

  AppointmentService({required FirebaseDatabase database}) 
      : _database = database;

  String _cleanName(String name) {
    return name.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
  }

  // Helper method to get user photo URL
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

  // Get count of active appointments for a student with a specific teacher
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
        
        // Count pending and accepted appointments as active
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

  // Create a new appointment when student knocks
  Future<Map<String, dynamic>> createAppointment({
    required UserModel student,
    required TeacherModel teacher,
    String? studentNote,
  }) async {
    try {
      if (student.studentNumber == null) {
        return {
          'success': false,
          'error': 'Student number is required for appointment',
        };
      }

      // Check active appointment count
      final activeCount = await getActiveAppointmentCount(
        studentNumber: student.studentNumber!,
        teacherUid: teacher.uid,
      );
      
      if (activeCount >= MAX_APPOINTMENTS_PER_TEACHER) {
        return {
          'success': false,
          'error': 'You have reached the maximum of $MAX_APPOINTMENTS_PER_TEACHER active appointments with this teacher. Please wait for existing appointments to be completed or cancelled.',
        };
      }

      // Check if student has a pending appointment
      final hasPending = await hasPendingAppointment(
        studentNumber: student.studentNumber!,
        teacherUid: teacher.uid,
      );
      
      if (hasPending) {
        return {
          'success': false,
          'error': 'You already have a pending appointment with this teacher. Please wait for a response.',
        };
      }

      // Generate appointment ID using student number as prefix
      final appointmentRef = _database
          .ref('appointments/${student.studentNumber}')
          .push();

      // Get student photo URL
      final studentPhotoUrl = await _getUserPhotoUrl(student.uid);

      // Create appointment data with server timestamp
      final appointmentData = {
        'studentUid': student.uid,
        'studentNumber': student.studentNumber!,
        'studentName': _cleanName(student.displayName),
        'studentPhotoUrl': studentPhotoUrl, // Add student photo
        'teacherUid': teacher.uid,
        'teacherName': _cleanName(teacher.displayName),
        'teacherPhotoUrl': teacher.photoUrl, // Use teacher photo from model
        'status': AppointmentStatus.pending.name,
        'createdAt': ServerValue.timestamp,
        'studentNote': studentNote,
      };

      await appointmentRef.set(appointmentData);

      await _database
          .ref('teacher_appointments/${teacher.uid}/${appointmentRef.key}')
          .set({
        'studentNumber': student.studentNumber,
        'appointmentId': appointmentRef.key,
        'status': AppointmentStatus.pending.name,
        'createdAt': ServerValue.timestamp,
      });

      // Send notification to teacher
      await _sendNotificationToTeacher(teacher.uid, student.displayName);

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

  // Enhanced method to get appointments with photo URLs
  Stream<List<AppointmentModel>> getTeacherActiveAppointments(String teacherUid) {
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
            
            // Ensure photo URLs are populated if missing
            if (appointmentData['studentPhotoUrl'] == null && appointmentData['studentUid'] != null) {
              appointmentData['studentPhotoUrl'] = await _getUserPhotoUrl(appointmentData['studentUid']);
            }
            if (appointmentData['teacherPhotoUrl'] == null && appointmentData['teacherUid'] != null) {
              appointmentData['teacherPhotoUrl'] = await _getUserPhotoUrl(appointmentData['teacherUid']);
            }
            
            final appointment = AppointmentModel.fromJson(appointmentId, appointmentData);
            
            // Include pending appointments and accepted appointments with active teacher actions
            final isActive = appointment.status == AppointmentStatus.pending ||
                           (appointment.status == AppointmentStatus.accepted && 
                            (appointment.teacherAction == TeacherAction.wait5Minutes ||
                             appointment.teacherAction == TeacherAction.meetNow ||
                             appointment.teacherAction == TeacherAction.meetLater));
                             
            if (isActive) {
              appointments.add(appointment);
            }
          }
        }
        
        appointments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      
      return appointments;
    });
  }

  // Enhanced method for all appointments with photos
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
            
            // Ensure photo URLs are populated if missing
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

  // Enhanced student appointments with photos
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
            
            // Ensure photo URLs are populated if missing
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
        
        // Sort by creation date (newest first)
        appointments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      
      return appointments;
    });
  }

  // Other methods remain the same...
  Future<bool> respondToAppointment({
    required String studentNumber,
    required String appointmentId,
    required String teacherUid,
    required TeacherAction action,
    String? teacherResponse,
    DateTime? scheduledTime,
  }) async {
    try {
      // Check if appointment exists
      final appointmentSnapshot = await _database
          .ref('appointments/$studentNumber/$appointmentId')
          .get();
          
      if (!appointmentSnapshot.exists) {
        debugPrint('Appointment not found');
        return false;
      }
      
      final updates = <String, dynamic>{};
      
      // Determine status based on action
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

      // Update main appointment record
      updates['appointments/$studentNumber/$appointmentId/status'] = newStatus.name;
      updates['appointments/$studentNumber/$appointmentId/respondedAt'] = 
          ServerValue.timestamp;
      updates['appointments/$studentNumber/$appointmentId/teacherAction'] = action.name;
      
      if (teacherResponse != null) {
        updates['appointments/$studentNumber/$appointmentId/teacherResponse'] = 
            teacherResponse;
      }
      
      if (scheduledTime != null && action == TeacherAction.meetLater) {
        updates['appointments/$studentNumber/$appointmentId/scheduledTime'] = 
            scheduledTime.millisecondsSinceEpoch;
      }

      // Update teacher's appointment index
      updates['teacher_appointments/$teacherUid/$appointmentId/status'] = newStatus.name;
      updates['teacher_appointments/$teacherUid/$appointmentId/respondedAt'] = 
          ServerValue.timestamp;

      // Perform atomic update
      await _database.ref().update(updates);

      // Send notification to student about the response
      await _sendNotificationToStudent(studentNumber, action, teacherResponse);

      // If wait 5 minutes, schedule a reminder
      if (action == TeacherAction.wait5Minutes) {
        await _scheduleWaitReminder(studentNumber, appointmentId, 5);
      }

      return true;
    } catch (e) {
      debugPrint('Error responding to appointment: $e');
      return false;
    }
  }

  // Get pending appointments for a teacher
  Stream<List<AppointmentModel>> getTeacherPendingAppointments(String teacherUid) {
    return _database
        .ref('teacher_appointments/$teacherUid')
        .orderByChild('status')
        .equalTo('pending')
        .onValue
        .asyncMap((event) async {
      final List<AppointmentModel> appointments = [];
      
      if (event.snapshot.exists && event.snapshot.value != null) {
        final indexData = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        // Fetch full appointment details for each pending appointment
        for (var entry in indexData.entries) {
          final appointmentIndex = Map<String, dynamic>.from(entry.value as Map);
          final studentNumber = appointmentIndex['studentNumber'] as String;
          final appointmentId = appointmentIndex['appointmentId'] as String;
          
          // Fetch full appointment data
          final appointmentSnapshot = await _database
              .ref('appointments/$studentNumber/$appointmentId')
              .get();
              
          if (appointmentSnapshot.exists) {
            final appointmentData = Map<String, dynamic>.from(appointmentSnapshot.value as Map);
            
            // Ensure photo URLs are populated if missing
            if (appointmentData['studentPhotoUrl'] == null && appointmentData['studentUid'] != null) {
              appointmentData['studentPhotoUrl'] = await _getUserPhotoUrl(appointmentData['studentUid']);
            }
            if (appointmentData['teacherPhotoUrl'] == null && appointmentData['teacherUid'] != null) {
              appointmentData['teacherPhotoUrl'] = await _getUserPhotoUrl(appointmentData['teacherUid']);
            }
            
            final appointment = AppointmentModel.fromJson(appointmentId, appointmentData);
            appointments.add(appointment);
          }
        }
        
        // Sort by creation date (oldest first for queue management)
        appointments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      
      return appointments;
    });
  }

  // Cancel appointment by student or teacher
  Future<bool> cancelAppointment({
    required String studentNumber,
    required String appointmentId,
    required String teacherUid,
    String ? reason,
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

  // Mark appointment as completed
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

  // Check if student has pending appointment with teacher
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
        
        // Check if any appointment is pending
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

  // Private helper methods
  Future<void> _sendNotificationToTeacher(String teacherUid, String studentName) async {
    // Implement push notification logic here
    // This would typically use Firebase Cloud Messaging (FCM)
    debugPrint('Notification sent to teacher: New appointment request from $studentName');
  }

  Future<void> _sendNotificationToStudent(
    String studentNumber, 
    TeacherAction action,
    String? message,
  ) async {
    // Implement push notification logic here
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
    // Implement reminder logic here
    // This could use local notifications or a scheduled cloud function
    debugPrint('Reminder scheduled for student $studentNumber in $minutes minutes');
  }
}