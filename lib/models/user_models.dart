import 'package:equatable/equatable.dart';

enum UserRole { student, teacher, admin }

abstract class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.displayName,
    this.profilePhotoUrl,
    this.lastLoginAt,
  });

  final String id;
  final String email;
  final UserRole role;
  final String displayName;
  final String? profilePhotoUrl;
  final DateTime? lastLoginAt;

  Map<String, dynamic> toMap();

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final role = UserRole.values.firstWhere(
      (r) => r.name == map['role'],
      orElse: () => UserRole.student,
    );

    switch (role) {
      case UserRole.student:
        return Student.fromMap(map);
      case UserRole.teacher:
        return Teacher.fromMap(map);
      case UserRole.admin:
        return Admin.fromMap(map);
    }
  }

  @override
  List<Object?> get props => [
    id,
    email,
    role,
    displayName,
    profilePhotoUrl,
    lastLoginAt,
  ];
}

class Student extends AppUser {
  const Student({
    required super.id,
    required super.email,
    required super.displayName,
    required this.studentNumber,
    super.profilePhotoUrl,
    super.lastLoginAt,
  }) : super(role: UserRole.student);

  final String studentNumber;

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'role': role.name,
      'displayName': displayName,
      'studentNumber': studentNumber,
      'profilePhotoUrl': profilePhotoUrl,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      studentNumber: map['studentNumber'] ?? '',
      profilePhotoUrl: map['profilePhotoUrl'],
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.parse(map['lastLoginAt'])
          : null,
    );
  }

  @override
  List<Object?> get props => [...super.props, studentNumber];
}

class Teacher extends AppUser {
  const Teacher({
    required super.id,
    required super.email,
    required super.displayName,
    this.department,
    super.profilePhotoUrl,
    super.lastLoginAt,
  }) : super(role: UserRole.teacher);

  final String? department;

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'role': role.name,
      'displayName': displayName,
      'department': department,
      'profilePhotoUrl': profilePhotoUrl,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  factory Teacher.fromMap(Map<String, dynamic> map) {
    return Teacher(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      department: map['department'],
      profilePhotoUrl: map['profilePhotoUrl'],
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.parse(map['lastLoginAt'])
          : null,
    );
  }

  @override
  List<Object?> get props => [...super.props, department];
}

class Admin extends AppUser {
  const Admin({
    required super.id,
    required super.email,
    required super.displayName,
    super.profilePhotoUrl,
    super.lastLoginAt,
  }) : super(role: UserRole.admin);

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'role': role.name,
      'displayName': displayName,
      'profilePhotoUrl': profilePhotoUrl,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  factory Admin.fromMap(Map<String, dynamic> map) {
    return Admin(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      profilePhotoUrl: map['profilePhotoUrl'],
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.parse(map['lastLoginAt'])
          : null,
    );
  }
}

// Helper class for Microsoft OAuth response
class MicrosoftUserInfo {
  const MicrosoftUserInfo({
    required this.id,
    required this.userPrincipalName,
    required this.displayName,
    required this.givenName,
    required this.surname,
    required this.mail,
  });

  final String id;
  final String userPrincipalName;
  final String displayName;
  final String givenName;
  final String surname;
  final String? mail;

  factory MicrosoftUserInfo.fromJson(Map<String, dynamic> json) {
    return MicrosoftUserInfo(
      id: json['id'] ?? '',
      userPrincipalName: json['userPrincipalName'] ?? '',
      displayName: json['displayName'] ?? '',
      givenName: json['givenName'] ?? '',
      surname: json['surname'] ?? '',
      mail: json['mail'],
    );
  }
}
