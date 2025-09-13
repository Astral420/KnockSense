import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/teacher_model.dart';

// Teacher model for the dashboard
class TeacherData {
  final String uid;
  final String displayName;
  final String email;
  final String activeStatus;
  final String? rfidUid;
  final String? teacherMsg;
  final String teacherID;
  final String initials;

  TeacherData({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.activeStatus,
    this.rfidUid,
    this.teacherMsg,
    required this.teacherID,
    required this.initials,
  });

  factory TeacherData.fromMap(String uid, Map<String, dynamic> data) {
    final displayName = data['displayName'] as String? ?? 'Unknown';
    return TeacherData(
      uid: uid,
      displayName: displayName,
      email: data['email'] as String? ?? '',
      activeStatus: data['active_status'] as String? ?? 'offline',
      rfidUid: data['rfid_uid'] as String?,
      teacherMsg: data['teacher_msg'] as String?,
      teacherID: data['teacherID'] as String? ?? '',
      initials: _getInitials(displayName),
    );
  }

  static String _getInitials(String name) {
    // Clean the name to remove roles like (Student) or (Faculty)
    final cleanedName = name.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

    if (cleanedName.isEmpty) {
      return '';
    }

    // Handle "LastName, FirstName" format
    if (cleanedName.contains(',')) {
      final parts = cleanedName.split(',').map((part) => part.trim()).toList();
      if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
    }

    // Handle "FirstName MiddleName LastName" format using regex
    final matches = RegExp(r'\b\w').allMatches(cleanedName);
    final initials = matches.map((m) => m.group(0)!).toList();

    if (initials.isEmpty) {
      return '';
    } else if (initials.length == 1) {
      return initials.first.toUpperCase();
    } else {
      return '${initials.first}${initials.last}'.toUpperCase();
    }
  }

  // Helper getter for photo URL (from user profile if needed)
  String? get photoUrl => null; // Will be populated from user data if needed
}

// Provider for Firebase Database instance (reuse from auth_provider)
final firebaseDatabaseProvider = Provider<FirebaseDatabase>(
  (ref) => FirebaseDatabase.instance,
);

// Stream provider for teachers data WITH photoUrl
final teachersStreamProvider = StreamProvider<List<TeacherModel>>((ref) {
  final database = ref.watch(firebaseDatabaseProvider);
  
  return database.ref('roles/teacher').onValue.asyncMap((event) async {
    final List<TeacherModel> teachers = [];
    
    if (event.snapshot.exists && event.snapshot.value != null) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      
      // Create a list of futures to fetch photoUrls concurrently
      final teacherFutures = data.entries.map((entry) async {
        final uid = entry.key;
        final teacherData = Map<String, dynamic>.from(entry.value as Map);
        
        // Fetch photoUrl from users/{uid}
        String? photoUrl;
        try {
          final userSnapshot = await database.ref('users/$uid').get();
          if (userSnapshot.exists) {
            final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
            photoUrl = userData['photoUrl'] as String?;
          }
        } catch (e) {
          // If fetching photoUrl fails, continue without it
          photoUrl = null;
        }
        
        return TeacherModel.fromMapWithPhoto(uid, teacherData, photoUrl);
      });
      
      // Wait for all photoUrl fetches to complete
      teachers.addAll(await Future.wait(teacherFutures));
      
      // Sort teachers by name
      teachers.sort((a, b) => a.displayName.compareTo(b.displayName));
    }
    
    return teachers;
  });
});

// Provider for a specific teacher by UID with photo URL
final teacherByUidProvider = StreamProvider.family<TeacherModel?, String>((ref, uid) {
  final database = ref.watch(firebaseDatabaseProvider);
  
  return database.ref('roles/teacher/$uid').onValue.asyncMap((event) async {
    if (event.snapshot.exists && event.snapshot.value != null) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final basicTeacher = TeacherModel.fromMap(uid, data);
      
      // Fetch photo URL from users/{uid}
      String? photoUrl;
      try {
        final userSnapshot = await database.ref('users/$uid').get();
        if (userSnapshot.exists) {
          final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
          photoUrl = userData['photoUrl'] as String?;
        }
      } catch (e) {
        photoUrl = null;
      }
      
      return basicTeacher.copyWith(photoUrl: photoUrl);
    }
    return null;
  });
});