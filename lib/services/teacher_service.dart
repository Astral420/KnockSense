import 'package:firebase_database/firebase_database.dart';

class TeacherService {
  final FirebaseDatabase _database;
  
  TeacherService({required FirebaseDatabase database}) : _database = database;
  
  // Enhanced: Update teacher status with proper timestamp reset
  Future<bool> updateTeacherStatus(String teacherUid, String newStatus) async {
    try {
      // Only allow switching between online and busy (offline is handled by presence system)
      if (newStatus != 'online' && newStatus != 'busy') {
        return false;
      }
      
      // Always update both status and timestamp to ensure fresh tracking
      final updates = {
        'active_status': newStatus,
        'status_changed_at': ServerValue.timestamp, // This will reset the timer
      };
      
      await _database
          .ref('roles/teacher/$teacherUid')
          .update(updates);
      
      print('✅ Teacher status updated: $teacherUid -> $newStatus with new timestamp');
      return true;
    } catch (e) {
      print('❌ Error updating teacher status: $e');
      return false;
    }
  }

  // NEW: Manual door unlock functionality
  Future<bool> requestManualDoorUnlock(String teacherUid, String teacherName, String teacherID) async {
  try {
    // Create unlock request with simplified structure
    final unlockRequest = {
      'status': 'pending',
      'teacherUid': teacherUid,
      'teacherName': teacherName,
      'requestedAt': ServerValue.timestamp,
      'unlockDuration': 4000, // 4 seconds in milliseconds
    };
    
    // Set the unlock request using teacherID as the key
    await _database
        .ref('door_unlock/$teacherID')
        .set(unlockRequest);
    
    print('🚪 Manual door unlock requested by: $teacherName ($teacherID)');
    return true;
  } catch (e) {
    print('❌ Error requesting manual door unlock: $e');
    return false;
  }
}

// NEW: Get manual unlock status using teacherID
Stream<String?> getManualUnlockStatus(String teacherUid) {
  // First we need to get the teacherID from the teacher's profile
  return _database
      .ref('roles/teacher/$teacherUid/teacherID')
      .onValue
      .asyncExpand((teacherIDEvent) {
    if (teacherIDEvent.snapshot.exists) {
      final teacherID = teacherIDEvent.snapshot.value as String;
      
      // Now listen to the door unlock status using teacherID
      return _database
          .ref('door_unlock/$teacherID/status')
          .onValue
          .map((statusEvent) {
        if (statusEvent.snapshot.exists) {
          return statusEvent.snapshot.value as String?;
        }
        return 'idle'; // Default status when no unlock request exists
      });
    }
    return Stream.value('idle'); // Default when teacherID not found
  });
}

// NEW: Get complete unlock data for a teacher
Stream<Map<String, dynamic>?> getManualUnlockData(String teacherID) {
  return _database
      .ref('door_unlock/$teacherID')
      .onValue
      .map((event) {
    if (event.snapshot.exists) {
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    }
    return null;
  });
}

// NEW: Clear completed unlock request (for cleanup)
Future<bool> clearUnlockRequest(String teacherID) async {
  try {
    await _database.ref('door_unlock/$teacherID').remove();
    return true;
  } catch (e) {
    print('❌ Error clearing unlock request: $e');
    return false;
  }
}

  // Enhanced: Stream that properly reacts to status changes and provides fresh timestamps
  Stream<TeacherStatusData> getTeacherStatusWithDuration(String teacherUid) {
    return _database
        .ref('roles/teacher/$teacherUid')
        .onValue
        .map((event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final status = data['active_status'] as String? ?? 'offline';
        int? timestamp;

        // For statuses set by the app, ALWAYS prioritize the manual timestamp field.
        if ((status == 'online' || status == 'busy') && data['status_changed_at'] != null) {
            timestamp = data['status_changed_at'] as int;
            
        } 
        // For automated offline status (from ESP32/presence), use the exit time.
        else if (status == 'offline' && data['last_exit_time'] != null) {
            timestamp = data['last_exit_time'] as int;
            
        } 
        // For automated online status (from ESP32/presence), use the entry time.
        else if (status == 'online' && data['last_entry_time'] != null) {
            timestamp = data['last_entry_time'] as int;
            
        } 
        // Final fallback to any available timestamp or the current time.
        else {
            timestamp = data['status_changed_at'] as int? ?? 
                        data['last_entry_time'] as int? ??
                        DateTime.now().millisecondsSinceEpoch;
            print('⚠️ Using fallback timestamp.');
        }
        
        final statusData = TeacherStatusData(
          status: status,
          changedAt: timestamp != null 
              ? DateTime.fromMillisecondsSinceEpoch(timestamp)
              : DateTime.now(),
        );
        
        print('📊 Status data for $teacherUid: ${statusData.status} since ${statusData.changedAt}');
        return statusData;
      }
      
      return TeacherStatusData(status: 'offline', changedAt: DateTime.now());
    });
  }
  
  // Enhanced: More responsive duration calculation with better formatting
  static String calculateDurationRealTime(DateTime? changedAt) {
    if (changedAt == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(changedAt);
    
    if (difference.inSeconds < 30) {
      return 'Just now';
    } else if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes min${minutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hr${hours == 1 ? '' : 's'} ago';
    } else {
      final days = difference.inDays;
      return '$days day${days == 1 ? '' : 's'} ago';
    }
  }

  // Keep the static version for compatibility
  static String calculateDuration(DateTime? changedAt) {
    return calculateDurationRealTime(changedAt);
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

class TeacherStatusData {
  final String status;
  final DateTime? changedAt;
  
  TeacherStatusData({
    required this.status,
    this.changedAt,
  });
  
  // Virtual property that recalculates duration on access
  String get duration => TeacherService.calculateDurationRealTime(changedAt);
  
  @override
  String toString() {
    return 'TeacherStatusData(status: $status, changedAt: $changedAt, duration: $duration)';
  }
}