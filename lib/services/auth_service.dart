import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:knocksense/models/user_models.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseDatabase _database;

  AuthService({required FirebaseAuth auth, required FirebaseDatabase database})
    : _auth = auth,
      _database = database;

  // Microsoft Sign In (for teachers and students)
  Future<UserModel?> signInWithMicrosoft() async {
    try {
      // Configure Microsoft provider
      final microsoftProvider = OAuthProvider('microsoft.com');
      microsoftProvider.setCustomParameters({
        'tenant': '3663e35d-c7bc-4b90-90e0-a67a1d53bb77', 
        'prompt': 'select_account',
      });

      // Sign in with redirect
      final userCredential = await _auth.signInWithProvider(microsoftProvider);

      if (userCredential.user != null) {
        return await _createOrUpdateUser(userCredential.user!);
      }
      return null;
    } catch (e) {
      throw Exception('Microsoft sign in failed: $e');
    }
  }

  // Email/Password Sign In (for admin only)
  Future<UserModel?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Check if admin (non-domain email)
        if (!_isSchoolEmail(email)) {
          return await _createOrUpdateUser(userCredential.user!, isAdmin: true);
        } else {
          // Not admin, sign out
          await _auth.signOut();
          throw Exception('Invalid admin credentials');
        }
      }
      return null;
    } catch (e) {
      throw Exception('Email sign in failed: $e');
    }
  }

  // Create or update user in Realtime Database
  Future<UserModel> _createOrUpdateUser(
    User firebaseUser, {  
    bool isAdmin = false,
  }) async {
    final String uid = firebaseUser.uid;
    final String email = firebaseUser.email ?? '';
    final String displayName = firebaseUser.displayName ?? email.split('@')[0];

    // Determine role
    UserRole role;
    String? studentNumber;


    if (isAdmin) {
      role = UserRole.admin;
    } else {
      final roleData = _determineRole(email);
      role = roleData['role'];
      studentNumber = roleData['studentNumber'];
    }

    // Check if user exists
    final userRef = _database.ref('users/$uid');
    final snapshot = await userRef.get();

    UserModel user;
    if (snapshot.exists) {
      // Update last login
      final existingData = Map<String, dynamic>.from(snapshot.value as Map);
      user = UserModel.fromJson(existingData);
      user = UserModel(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        role: user.role,
        studentNumber: user.studentNumber,
        createdAt: user.createdAt,
        lastLogin: DateTime.now(),
      );
    } else {
      // Create new user
      user = UserModel(
        uid: uid,
        email: email,
        displayName: displayName,
        role: role,
        studentNumber: studentNumber,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );
    }

    // Save to database
    await userRef.set(user.toJson());

    // Add to role-specific list for easy querying
    await _database.ref('roles/${role.name}/$uid').set({
      'email': email,
      'displayName': displayName,
      'studentNumber': studentNumber,
    });

    return user;
  }

  // Determine role from email
  Map<String, dynamic> _determineRole(String email) {
    // Check if it's a school email
    if (_isSchoolEmail(email)) {
      // Extract student number using regex
      final studentNumberMatch = RegExp(r'\.(\d{6})@').firstMatch(email);

      if (studentNumberMatch != null) {
        return {
          'role': UserRole.student,
          'studentNumber': studentNumberMatch.group(1),
        };
      } else {
        return {'role': UserRole.teacher, 'studentNumber': null};
      }
    }

    // Default to teacher if not school email (shouldn't happen with Microsoft auth)
    return {'role': UserRole.teacher, 'studentNumber': null};
  }

  // Check if email is from school domain
  bool _isSchoolEmail(String email) {
    return email.endsWith('@malolos.sti.edu.ph');
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;
}
