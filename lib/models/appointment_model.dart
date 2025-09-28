class AppointmentModel {
  final String appointmentId;
  final String studentUid;
  final String studentNumber;
  final String studentName;
  final String? studentPhotoUrl;
  final String teacherUid;
  final String teacherName;
  final String? teacherPhotoUrl;
  final AppointmentStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? studentNote;
  final String? teacherResponse;
  final TeacherAction? teacherAction;
  final DateTime? scheduledTime; // This now represents the actual appointment date/time
  final bool isScheduled; // New field to distinguish scheduled vs immediate appointments
  final bool notificationSent; // Track if near-appointment notification was sent

  String get cleanedStudentName {
    return studentName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
  }

  String get cleanedTeacherName {
    return teacherName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
  }

  // Check if appointment is today
  bool get isToday {
    final now = DateTime.now();
    final appointmentDate = scheduledTime ?? createdAt;
    return appointmentDate.year == now.year &&
           appointmentDate.month == now.month &&
           appointmentDate.day == now.day;
  }

  // Check if appointment is in the future
  bool get isFuture {
    if (scheduledTime == null) return false;
    final now = DateTime.now();
    return scheduledTime!.isAfter(now) && !isToday;
  }

  // Check if appointment is near (within 15 minutes)
  bool get isNear {
    if (scheduledTime == null) return false;
    final now = DateTime.now();
    final difference = scheduledTime!.difference(now);
    return difference.inMinutes <= 10 && difference.inMinutes >= 5;
  }

  AppointmentModel({
    required this.appointmentId,
    required this.studentUid,
    required this.studentNumber,
    required this.studentName,
    this.studentPhotoUrl,
    required this.teacherUid,
    required this.teacherName,
    this.teacherPhotoUrl,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.studentNote,
    this.teacherResponse,
    this.teacherAction,
    this.scheduledTime,
    this.isScheduled = false,
    this.notificationSent = false,
  });

  factory AppointmentModel.fromJson(String id, Map<String, dynamic> json) {
    DateTime? parseToDateTime(dynamic value) {
      if (value == null) return null;
      
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else if (value is double) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      } else if (value is Map) {
        print('Warning: Received ServerValue.timestamp placeholder during read: $value');
        return DateTime.now();
      } else if (value is String) {
        try {
          final intValue = int.parse(value);
          return DateTime.fromMillisecondsSinceEpoch(intValue);
        } catch (e) {
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
      studentPhotoUrl: json['studentPhotoUrl'] as String?,
      teacherUid: json['teacherUid'] as String,
      teacherName: json['teacherName'] as String,
      teacherPhotoUrl: json['teacherPhotoUrl'] as String?,
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
      isScheduled: json['isScheduled'] ?? false,
      notificationSent: json['notificationSent'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'studentUid': studentUid,
    'studentNumber': studentNumber,
    'studentName': studentName,
    'studentPhotoUrl': studentPhotoUrl,
    'teacherUid': teacherUid,
    'teacherName': teacherName,
    'teacherPhotoUrl': teacherPhotoUrl,
    'status': status.name,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'respondedAt': respondedAt?.millisecondsSinceEpoch,
    'studentNote': studentNote,
    'teacherResponse': teacherResponse,
    'teacherAction': teacherAction?.name,
    'scheduledTime': scheduledTime?.millisecondsSinceEpoch,
    'isScheduled': isScheduled,
    'notificationSent': notificationSent,
  };

  AppointmentModel copyWith({
    String? appointmentId,
    String? studentUid,
    String? studentNumber,
    String? studentName,
    String? studentPhotoUrl,
    String? teacherUid,
    String? teacherName,
    String? teacherPhotoUrl,
    AppointmentStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? studentNote,
    String? teacherResponse,
    TeacherAction? teacherAction,
    DateTime? scheduledTime,
    bool? isScheduled,
    bool? notificationSent,
  }) {
    return AppointmentModel(
      appointmentId: appointmentId ?? this.appointmentId,
      studentUid: studentUid ?? this.studentUid,
      studentNumber: studentNumber ?? this.studentNumber,
      studentName: studentName ?? this.studentName,
      studentPhotoUrl: studentPhotoUrl ?? this.studentPhotoUrl,
      teacherUid: teacherUid ?? this.teacherUid,
      teacherName: teacherName ?? this.teacherName,
      teacherPhotoUrl: teacherPhotoUrl ?? this.teacherPhotoUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      studentNote: studentNote ?? this.studentNote,
      teacherResponse: teacherResponse ?? this.teacherResponse,
      teacherAction: teacherAction ?? this.teacherAction,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isScheduled: isScheduled ?? this.isScheduled,
      notificationSent: notificationSent ?? this.notificationSent,
    );
  }

  @override
  String toString() {
    return 'AppointmentModel(id: $appointmentId, student: $studentName, teacher: $teacherName, status: $status, scheduledTime: $scheduledTime, isScheduled: $isScheduled)';
  }
}

enum AppointmentStatus {
  pending,
  accepted,
  denied,
  completed,
  cancelled,
}

enum TeacherAction {
  pending,
  meetNow,
  wait5Minutes,
  meetLater,
  reject,
}