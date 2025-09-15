import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:knocksense/models/appointment_model.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/models/teacher_model.dart';

class AppointmentService {
  final FirebaseDatabase _database;

  AppointmentService({required FirebaseDatabase database}) 
      : _database = database;

  // Create a new appointment when student knocks
  Future<String?> createAppointment({
    required UserModel student,
    required TeacherModel teacher,
    String? studentNote,
  }) async {
    try {
      if (student.studentNumber == null) {
        throw Exception('Student number is required for appointment');
      }

      // Generate appointment ID using student number as prefix
      final appointmentRef = _database
          .ref('appointments/${student.studentNumber}')
          .push();

      final appointment = AppointmentModel(
        appointmentId: appointmentRef.key!,
        studentUid: student.uid,
        studentNumber: student.studentNumber!,
        studentName: student.displayName,
        teacherUid: teacher.uid,
        teacherName: teacher.displayName,
        status: AppointmentStatus.pending,
        createdAt: DateTime.now(),
        studentNote: studentNote,
      );

      // Save to database under student's number
      await appointmentRef.set(appointment.toJson());

      // Also create an index for teacher to see their pending appointments
      await _database
          .ref('teacher_appointments/${teacher.uid}/${appointmentRef.key}')
          .set({
        'studentNumber': student.studentNumber,
        'appointmentId': appointmentRef.key,
        'status': AppointmentStatus.pending.name,
        'createdAt': appointment.createdAt.toIso8601String(),
      });

      // Send notification to teacher (implement push notification here)
      await _sendNotificationToTeacher(teacher.uid, student.displayName);

      return appointmentRef.key;
    } catch (e) {
      debugPrint('Error creating appointment: $e');
      return null;
    }
  }

  // Teacher responds to appointment
  Future<bool> respondToAppointment({
    required String studentNumber,
    required String appointmentId,
    required String teacherUid,
    required TeacherAction action,
    String? teacherResponse,
    DateTime? scheduledTime,
  }) async {
    try {
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
            scheduledTime.toIso8601String();
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

  // Get all appointments for a student
  Stream<List<AppointmentModel>> getStudentAppointments(String studentNumber) {
    return _database
        .ref('appointments/$studentNumber')
        .orderByChild('createdAt')
        .onValue
        .map((event) {
      final List<AppointmentModel> appointments = [];
      
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        data.forEach((key, value) {
          appointments.add(AppointmentModel.fromJson(
            key,
            Map<String, dynamic>.from(value as Map),
          ));
        });
        
        // Sort by creation date (newest first)
        appointments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      
      return appointments;
    });
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
            appointments.add(AppointmentModel.fromJson(
              appointmentId,
              Map<String, dynamic>.from(appointmentSnapshot.value as Map),
            ));
          }
        }
        
        // Sort by creation date (oldest first for queue management)
        appointments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      
      return appointments;
    });
  }

  // Get all appointments for a teacher (including history)
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
            appointments.add(AppointmentModel.fromJson(
              appointmentId,
              Map<String, dynamic>.from(appointmentSnapshot.value as Map),
            ));
          }
        }
        
        appointments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      
      return appointments;
    });
  }

  // Cancel appointment by student
  Future<bool> cancelAppointment({
    required String studentNumber,
    required String appointmentId,
    required String teacherUid,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      updates['appointments/$studentNumber/$appointmentId/status'] = 
          AppointmentStatus.cancelled.name;
      updates['teacher_appointments/$teacherUid/$appointmentId/status'] = 
          AppointmentStatus.cancelled.name;
      
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