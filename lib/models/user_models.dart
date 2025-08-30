class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? studentNumber;
  final DateTime createdAt;
  final DateTime lastLogin;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.studentNumber,
    required this.createdAt,
    required this.lastLogin,
  });

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'role': role.name,
    'studentNumber': studentNumber,
    'createdAt': createdAt.toIso8601String(),
    'lastLogin': lastLogin.toIso8601String(),
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    uid: json['uid'],
    email: json['email'],
    displayName: json['displayName'],
    role: UserRole.values.firstWhere((e) => e.name == json['role']),
    studentNumber: json['studentNumber'],
    createdAt: DateTime.parse(json['createdAt']),
    lastLogin: DateTime.parse(json['lastLogin']),
  );
}

enum UserRole { admin, teacher, student }
