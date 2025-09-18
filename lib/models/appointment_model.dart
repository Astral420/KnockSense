class AppointmentModel {
  final String appointmentId;
  final String studentUid;
  final String studentNumber;
  final String studentName;
  final String teacherUid;
  final String teacherName;
  final AppointmentStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? studentNote;
  final String? teacherResponse;
  final TeacherAction? teacherAction;
  final DateTime? scheduledTime; // For "meet later" option

  AppointmentModel({
    required this.appointmentId,
    required this.studentUid,
    required this.studentNumber,
    required this.studentName,
    required this.teacherUid,
    required this.teacherName,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.studentNote,
    this.teacherResponse,
    this.teacherAction,
    this.scheduledTime,
  });

  factory AppointmentModel.fromJson(String id, Map<String, dynamic> json) {

    DateTime? parseToDateTime(dynamic value) {
      if (value == null) return null;
      
      // Handle different timestamp formats from Firebase
      if (value is int) {
        // Standard milliseconds timestamp
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else if (value is double) {
        // Sometimes Firebase returns double
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      } else if (value is Map) {
        // Handle ServerValue.timestamp placeholder (shouldn't happen when reading)
        // This is usually only present during write operations
        print('Warning: Received ServerValue.timestamp placeholder during read: $value');
        return DateTime.now(); // Fallback
      } else if (value is String) {
        // Handle string timestamps (backup parsing)
        try {
          final intValue = int.parse(value);
          return DateTime.fromMillisecondsSinceEpoch(intValue);
        } catch (e) {
          // Try parsing as ISO string
          return DateTime.tryParse(value);
        }
      }
      
      print('Warning: Unknown timestamp format: $value (${value.runtimeType})');
      return null;
    }

    DateTime parseRequiredDateTime(dynamic value, String fieldName) {
      final dateTime = parseToDateTime(value);
      if (dateTime == null) {
        print('Warning: Could not parse $fieldName: $value, using current time');
        return DateTime.now();
      }
      return dateTime;
    }

    return AppointmentModel(
      appointmentId: id,
      studentUid: json['studentUid'] as String,
      studentNumber: json['studentNumber'] as String,
      studentName: json['studentName'] as String,
      teacherUid: json['teacherUid'] as String,
      teacherName: json['teacherName'] as String,
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AppointmentStatus.pending,
      ),
      createdAt: parseRequiredDateTime(json['createdAt'], 'createdAt'),
      respondedAt: parseToDateTime(json['respondedAt']),
      studentNote: json['studentNote'] as String?,
      teacherResponse: json['teacherResponse'] as String?,
      teacherAction: json['teacherAction'] != null
          ? TeacherAction.values.firstWhere(
              (e) => e.name == json['teacherAction'],
              orElse: () => TeacherAction.pending,
            )
          : null,
      scheduledTime: parseToDateTime(json['scheduledTime']),
    );
  }

  Map<String, dynamic> toJson() => {
    'studentUid': studentUid,
    'studentNumber': studentNumber,
    'studentName': studentName,
    'teacherUid': teacherUid,
    'teacherName': teacherName,
    'status': status.name,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'respondedAt': respondedAt?.millisecondsSinceEpoch,
    'studentNote': studentNote,
    'teacherResponse': teacherResponse,
    'teacherAction': teacherAction?.name,
    'scheduledTime': scheduledTime?.millisecondsSinceEpoch,
  };

  AppointmentModel copyWith({
    String? appointmentId,
    String? studentUid,
    String? studentNumber,
    String? studentName,
    String? teacherUid,
    String? teacherName,
    AppointmentStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? studentNote,
    String? teacherResponse,
    TeacherAction? teacherAction,
    DateTime? scheduledTime,
  }) {
    return AppointmentModel(
      appointmentId: appointmentId ?? this.appointmentId,
      studentUid: studentUid ?? this.studentUid,
      studentNumber: studentNumber ?? this.studentNumber,
      studentName: studentName ?? this.studentName,
      teacherUid: teacherUid ?? this.teacherUid,
      teacherName: teacherName ?? this.teacherName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      studentNote: studentNote ?? this.studentNote,
      teacherResponse: teacherResponse ?? this.teacherResponse,
      teacherAction: teacherAction ?? this.teacherAction,
      scheduledTime: scheduledTime ?? this.scheduledTime,
    );
  }

  @override
  String toString() {
    return 'AppointmentModel(id: $appointmentId, student: $studentName, teacher: $teacherName, status: $status, createdAt: $createdAt)';
  }
}

enum AppointmentStatus {
  pending,   // Initial state when student knocks
  accepted,  // Teacher accepted the appointment
  denied,    // Teacher rejected the appointment
  completed, // Appointment was completed
  cancelled, // Student cancelled the appointment
}

enum TeacherAction {
  pending,      // No action taken yet
  meetNow,      // Meet the student immediately
  wait5Minutes, // Ask student to wait 5 minutes
  meetLater,    // Schedule for later time
  reject,       // Reject the appointment
}