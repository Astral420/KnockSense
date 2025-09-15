
class KnockedHistoryModel {
  final String id;
  final String teacherUid;
  final String teacherName;
  final String teacherInitials;
  final String? teacherPhotoUrl;
  final String studentNumber;
  final String studentName;
  final DateTime knockedAt;
  final KnockedStatus status;
  final String? requestMessage;
  final DateTime? respondedAt;
  final String? teacherResponse;

  KnockedHistoryModel({
    required this.id,
    required this.teacherUid,
    required this.teacherName,
    required this.teacherInitials,
    this.teacherPhotoUrl,
    required this.studentNumber,
    required this.studentName,
    required this.knockedAt,
    required this.status,
    this.requestMessage,
    this.respondedAt,
    this.teacherResponse,
  });

  factory KnockedHistoryModel.fromJson(String id, Map<String, dynamic> json) {
    return KnockedHistoryModel(
      id: id,
      teacherUid: json['teacherUid'] as String,
      teacherName: json['teacherName'] as String,
      teacherInitials: json['teacherInitials'] as String,
      teacherPhotoUrl: json['teacherPhotoUrl'] as String?,
      studentNumber: json['studentNumber'] as String,
      studentName: json['studentName'] as String,
      knockedAt: DateTime.parse(json['knockedAt'] as String),
      status: KnockedStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => KnockedStatus.pending,
      ),
      requestMessage: json['requestMessage'] as String?,
      respondedAt: json['respondedAt'] != null 
          ? DateTime.parse(json['respondedAt'] as String)
          : null,
      teacherResponse: json['teacherResponse'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'teacherUid': teacherUid,
    'teacherName': teacherName,
    'teacherInitials': teacherInitials,
    'teacherPhotoUrl': teacherPhotoUrl,
    'studentNumber': studentNumber,
    'studentName': studentName,
    'knockedAt': knockedAt.toIso8601String(),
    'status': status.name,
    'requestMessage': requestMessage,
    'respondedAt': respondedAt?.toIso8601String(),
    'teacherResponse': teacherResponse,
  };

  KnockedHistoryModel copyWith({
    String? id,
    String? teacherUid,
    String? teacherName,
    String? teacherInitials,
    String? teacherPhotoUrl,
    String? studentNumber,
    String? studentName,
    DateTime? knockedAt,
    KnockedStatus? status,
    String? requestMessage,
    DateTime? respondedAt,
    String? teacherResponse,
  }) {
    return KnockedHistoryModel(
      id: id ?? this.id,
      teacherUid: teacherUid ?? this.teacherUid,
      teacherName: teacherName ?? this.teacherName,
      teacherInitials: teacherInitials ?? this.teacherInitials,
      teacherPhotoUrl: teacherPhotoUrl ?? this.teacherPhotoUrl,
      studentNumber: studentNumber ?? this.studentNumber,
      studentName: studentName ?? this.studentName,
      knockedAt: knockedAt ?? this.knockedAt,
      status: status ?? this.status,
      requestMessage: requestMessage ?? this.requestMessage,
      respondedAt: respondedAt ?? this.respondedAt,
      teacherResponse: teacherResponse ?? this.teacherResponse,
    );
  }

  @override
  String toString() {
    return 'KnockedHistoryModel(id: $id, teacherName: $teacherName, studentNumber: $studentNumber, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KnockedHistoryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum KnockedStatus {
  pending,    // Waiting for teacher response
  waiting,    // Teacher asked student to wait
  completed,  // Appointment was completed
  denied,     // Teacher rejected the appointment
}