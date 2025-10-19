// provider/activity_logs_provider.dart

//import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/provider/auth_provider.dart';

// Model for activity log entry
class ActivityLog {
  final String teacherID;
  final String teacherName;
  final String? rfidUid;
  final String email;
  final DateTime timestamp;
  final String action; // 'entry' or 'exit'
  final String? photoUrl;

  ActivityLog({
    required this.teacherID,
    required this.teacherName,
    this.rfidUid,
    required this.email,
    required this.timestamp,
    required this.action,
    this.photoUrl,
  });

  // Helper to check if entry or exit
  bool get isEntry => action == 'entry';
  
  // Format time for display
  String get formattedTime {
    final hour = timestamp.hour == 0 ? 12 : (timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour);
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final ampm = timestamp.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $ampm";
  }
  
  // Format date for display
  String get formattedDate {
    return "${timestamp.month.toString().padLeft(2, '0')}/"
           "${timestamp.day.toString().padLeft(2, '0')}/"
           "${timestamp.year.toString().substring(2)}";
  }
}

// Stream provider for activity logs
final activityLogsStreamProvider = StreamProvider<List<ActivityLog>>((ref) {
  final database = ref.watch(firebaseDatabaseProvider);
  
  return database.ref('attendance_logs').onValue.asyncMap((event) async {
    final List<ActivityLog> logs = [];
    
    if (event.snapshot.exists && event.snapshot.value != null) {
      final attendanceData = Map<String, dynamic>.from(event.snapshot.value as Map);
      
      // Process each teacher's logs
      for (final teacherEntry in attendanceData.entries) {
        final teacherID = teacherEntry.key; // e.g., "Teacher_001"
        final teacherData = Map<String, dynamic>.from(teacherEntry.value as Map);
        
        // Fetch teacher details from roles/teacher
        TeacherInfo? teacherInfo;
        try {
          final teacherSnapshot = await database.ref('roles/teacher').get();
          if (teacherSnapshot.exists) {
            final teachersData = Map<String, dynamic>.from(teacherSnapshot.value as Map);
            
            // Find the teacher with matching teacherID
            for (final entry in teachersData.entries) {
              final data = Map<String, dynamic>.from(entry.value as Map);
              if (data['teacherID'] == teacherID) {
                teacherInfo = TeacherInfo(
                  uid: entry.key,
                  displayName: data['displayName'] ?? 'Unknown',
                  email: data['email'] ?? '',
                  rfidUid: data['rfid_uid'] as String?,
                  teacherID: teacherID,
                );
                
                // Fetch photo URL from users node
                try {
                  final userSnapshot = await database.ref('users/${entry.key}').get();
                  if (userSnapshot.exists) {
                    final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
                    teacherInfo = teacherInfo.copyWith(
                      photoUrl: userData['photoUrl'] as String?,
                    );
                  }
                } catch (e) {
                  // Continue without photo URL
                }
                break;
              }
            }
          }
        } catch (e) {
          print('Error fetching teacher info for $teacherID: $e');
        }
        
        // Process individual logs if they exist
        if (teacherData['logs'] != null) {
          final logsData = teacherData['logs'];
          
          if (logsData is List) {
            // Process array of logs
            for (var logEntry in logsData) {
              if (logEntry != null && logEntry is Map) {
                final logData = Map<String, dynamic>.from(logEntry);
                final timestamp = _parseTimestamp(logData['timestamp']);
                final action = logData['action'] as String? ?? 'entry';
                
                if (timestamp != null && teacherInfo != null) {
                  logs.add(ActivityLog(
                    teacherID: teacherID,
                    teacherName: _formatTeacherName(teacherInfo.displayName),
                    rfidUid: teacherInfo.rfidUid,
                    email: teacherInfo.email,
                    timestamp: timestamp,
                    action: action,
                    photoUrl: teacherInfo.photoUrl,
                  ));
                }
              }
            }
          } else if (logsData is Map) {
            // Process map of logs (indexed by keys)
            final logsMap = Map<String, dynamic>.from(logsData);
            for (var logEntry in logsMap.values) {
              if (logEntry != null && logEntry is Map) {
                final logData = Map<String, dynamic>.from(logEntry);
                final timestamp = _parseTimestamp(logData['timestamp']);
                final action = logData['action'] as String? ?? 'entry';
                
                if (timestamp != null && teacherInfo != null) {
                  logs.add(ActivityLog(
                    teacherID: teacherID,
                    teacherName: _formatTeacherName(teacherInfo.displayName),
                    rfidUid: teacherInfo.rfidUid,
                    email: teacherInfo.email,
                    timestamp: timestamp,
                    action: action,
                    photoUrl: teacherInfo.photoUrl,
                  ));
                }
              }
            }
          }
        }
        
        // REMOVED: Processing of last_activity to prevent duplicates
        // The logs array/map already contains all activity entries
        // including the most recent one, so we don't need to add last_activity separately
      }
    }
    
    // Sort logs by timestamp (newest first)
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return logs;
  });
});

// Filtered logs provider based on date range
final filteredActivityLogsProvider = Provider<AsyncValue<List<ActivityLog>>>((ref) {
  final logsAsync = ref.watch(activityLogsStreamProvider);
  final startDate = ref.watch(startDateProvider);
  final endDate = ref.watch(endDateProvider);
  
  return logsAsync.when(
    data: (logs) {
      if (startDate == null && endDate == null) {
        return AsyncValue.data(logs);
      }
      
      final filtered = logs.where((log) {
        final logDate = DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day);
        
        if (startDate != null) {
          final start = DateTime(startDate.year, startDate.month, startDate.day);
          if (logDate.isBefore(start)) return false;
        }
        
        if (endDate != null) {
          final end = DateTime(endDate.year, endDate.month, endDate.day);
          if (logDate.isAfter(end)) return false;
        }
        
        return true;
      }).toList();
      
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Date range filter providers (moved from admin_activity_logs_screen.dart)
final startDateProvider = StateProvider<DateTime?>((ref) => null);
final endDateProvider = StateProvider<DateTime?>((ref) => null);

// Helper function to parse timestamp
DateTime? _parseTimestamp(dynamic timestamp) {
  if (timestamp == null) return null;
  
  if (timestamp is int) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  } else if (timestamp is String) {
    // Try parsing as milliseconds string
    final millis = int.tryParse(timestamp);
    if (millis != null) {
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    // Try parsing as ISO string
    return DateTime.tryParse(timestamp);
  }
  
  return null;
}

// Helper function to format teacher name
String _formatTeacherName(String displayName) {
  // Remove "(Faculty)" or any parenthetical content
  String cleanedName = displayName.replaceAll(RegExp(r'\s*\(.*?\)\s*'), '').trim();
  
  // Handle "LastName, FirstName" format
  if (cleanedName.contains(',')) {
    final parts = cleanedName.split(',').map((part) => part.trim()).toList();
    if (parts.length == 2) {
      // Return as "FirstName LastName" format with Prof. prefix
      return 'Prof. ${parts[1]} ${parts[0]}';
    }
  }
  
  // Add Prof. prefix if not already present
  if (!cleanedName.startsWith('Prof.')) {
    return 'Prof. $cleanedName';
  }
  
  return cleanedName;
}

// Helper class for teacher info
class TeacherInfo {
  final String uid;
  final String displayName;
  final String email;
  final String? rfidUid;
  final String teacherID;
  final String? photoUrl;

  TeacherInfo({
    required this.uid,
    required this.displayName,
    required this.email,
    this.rfidUid,
    required this.teacherID,
    this.photoUrl,
  });

  TeacherInfo copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? rfidUid,
    String? teacherID,
    String? photoUrl,
  }) {
    return TeacherInfo(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      rfidUid: rfidUid ?? this.rfidUid,
      teacherID: teacherID ?? this.teacherID,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}