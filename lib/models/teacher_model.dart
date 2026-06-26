class TeacherModel {
  final String uid;
  final String displayName;
  final String email;
  final String activeStatus;
  final String? rfidUid;
  final String? teacherMsg;
  final String teacherID;
  final String initials;
  final String? photoUrl;

  TeacherModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.activeStatus,
    this.rfidUid,
    this.teacherMsg,
    required this.teacherID,
    required this.initials,
    this.photoUrl,
  });

  factory TeacherModel.fromMap(String uid, Map<String, dynamic> data) {
    final displayName = data['displayName'] as String? ?? 'Unknown';
    return TeacherModel(
      uid: uid,
      displayName: displayName,
      email: data['email'] as String? ?? '',
      activeStatus: data['active_status'] as String? ?? 'offline',
      rfidUid: data['rfid_uid'] as String?,
      teacherMsg: data['teacher_msg'] as String?,
      teacherID: data['teacherID'] as String? ?? '',
      initials: _getInitials(displayName),
      photoUrl: null, // Will be populated separately if needed
    );
  }

  // Factory constructor that includes photo URL from user profile
  factory TeacherModel.fromMapWithPhoto(String uid, Map<String, dynamic> data, String? photoUrl) {
    final displayName = data['displayName'] as String? ?? 'Unknown';
    return TeacherModel(
      uid: uid,
      displayName: displayName,
      email: data['email'] as String? ?? '',
      activeStatus: data['active_status'] as String? ?? 'offline',
      rfidUid: data['rfid_uid'] as String?,
      teacherMsg: data['teacher_msg'] as String?,
      teacherID: data['teacherID'] as String? ?? '',
      initials: _getInitials(displayName),
      photoUrl: photoUrl,
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

  // CopyWith method for creating modified instances
  TeacherModel copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? activeStatus,
    String? rfidUid,
    String? teacherMsg,
    String? teacherID,
    String? initials,
    String? photoUrl,
  }) {
    return TeacherModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      activeStatus: activeStatus ?? this.activeStatus,
      rfidUid: rfidUid ?? this.rfidUid,
      teacherMsg: teacherMsg ?? this.teacherMsg,
      teacherID: teacherID ?? this.teacherID,
      initials: initials ?? this.initials,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  // JSON serialization methods if needed for caching or local storage
  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'activeStatus': activeStatus,
        'rfidUid': rfidUid,
        'teacherMsg': teacherMsg,
        'teacherID': teacherID,
        'initials': initials,
        'photoUrl': photoUrl,
      };

  factory TeacherModel.fromJson(Map<String, dynamic> json) => TeacherModel(
        uid: json['uid'] as String,
        displayName: json['displayName'] as String,
        email: json['email'] as String,
        activeStatus: json['activeStatus'] as String,
        rfidUid: json['rfidUid'] as String?,
        teacherMsg: json['teacherMsg'] as String?,
        teacherID: json['teacherID'] as String,
        initials: json['initials'] as String,
        photoUrl: json['photoUrl'] as String?,
      );

  @override
  String toString() {
    return 'TeacherModel(uid: $uid, displayName: $displayName, teacherID: $teacherID, activeStatus: $activeStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TeacherModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}