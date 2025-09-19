import 'package:firebase_database/firebase_database.dart';
import 'package:knocksense/models/user_models.dart';

class TeacherService {
  final FirebaseDatabase _database;
  
  TeacherService({required FirebaseDatabase database}) : _database = database;
  
  // Update teacher status
  Future<bool> updateTeacherStatus(String teacherUid, String newStatus) async {
    try {
      // Don't allow status change if currently offline
      final currentStatusSnapshot = await _database
          .ref('roles/teacher/$teacherUid/active_status')
          .get();
      
      if (currentStatusSnapshot.exists) {
        final currentStatus = currentStatusSnapshot.value as String;
        if (currentStatus.toLowerCase() == 'offline') {
          return false; // Can't change status when offline
        }
      }
      
      // Only allow switching between online and busy
      if (newStatus != 'online' && newStatus != 'busy') {
        return false;
      }
      
      await _database
          .ref('roles/teacher/$teacherUid/active_status')
          .set(newStatus);
      
      return true;
    } catch (e) {
      print('Error updating teacher status: $e');
      return false;
    }
  }
  
  // Update teacher note/message
  Future<bool> updateTeacherNote(String teacherUid, String? note) async {
    try {
      await _database
          .ref('roles/teacher/$teacherUid/teacher_msg')
          .set(note);
      
      return true;
    } catch (e) {
      print('Error updating teacher note: $e');
      return false;
    }
  }
  
  // Get teacher's current status
  Stream<String> getTeacherStatus(String teacherUid) {
    return _database
        .ref('roles/teacher/$teacherUid/active_status')
        .onValue
        .map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as String;
      }
      return 'offline';
    });
  }
  
  // Get teacher's current note
  Stream<String?> getTeacherNote(String teacherUid) {
    return _database
        .ref('roles/teacher/$teacherUid/teacher_msg')
        .onValue
        .map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as String?;
      }
      return null;
    });
  }
}