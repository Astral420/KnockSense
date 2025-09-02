class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? studentNumber;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime lastLogin;
  
  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.studentNumber,
    this.photoUrl,
    required this.createdAt,
    required this.lastLogin,
  });

   UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    String? studentNumber,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastLogin,
    
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      studentNumber: studentNumber ?? this.studentNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'role': role.name,
    'studentNumber': studentNumber,
    'photoUrl' : photoUrl,
    'createdAt': createdAt.toIso8601String(),
    'lastLogin': lastLogin.toIso8601String(),
    
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    uid: json['uid'],
    email: json['email'],
    displayName: json['displayName'],
    role: UserRole.values.firstWhere((e) => e.name == json['role']),
    studentNumber: json['studentNumber'],
    photoUrl: json['photoUrl'],
    createdAt: DateTime.parse(json['createdAt']),
    lastLogin: DateTime.parse(json['lastLogin']),
  );
}

enum UserRole { admin, teacher, student }
