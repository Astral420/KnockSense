import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/services/microsoft_graph_service.dart';
import 'package:knocksense/services/notification_service.dart';

class AuthBanException implements Exception {
  final String message;

  AuthBanException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseDatabase _database;
  final GraphService _graphService;

  AuthService({
    required FirebaseAuth auth,
    required FirebaseDatabase database,
    required GraphService graphService,
  })  : _auth = auth,
        _database = database,
        _graphService = graphService;

  Future<String?> _getBanMessage(String? email) async {
    if (email == null || email.isEmpty) {
      return null;
    }

    final normalizedEmail = _normalizeEmail(email);
    final emailKey = _encodeKey(normalizedEmail);
    final snapshot = await _database.ref('banned_teacher_emails/$emailKey').get();
    debugPrint('[AuthService] Ban lookup for "$normalizedEmail" -> exists=${snapshot.exists} value=${snapshot.value}');

    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final data = snapshot.value is Map
        ? Map<String, dynamic>.from(snapshot.value as Map)
        : <String, dynamic>{};

    final reason = data['reason'] as String?;
    if (reason != null && reason.trim().isNotEmpty) {
      return reason;
    }

    return 'This account has been permanently removed. Please contact an administrator to regain access.';
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  String _encodeKey(String key) => key.replaceAll(RegExp(r'[.#$\[\]]'), '_');

  // Microsoft Sign In (for teachers and students)
  Future<UserModel?> signInWithMicrosoft() async {
  try {
    final microsoftProvider = MicrosoftAuthProvider();
    microsoftProvider.setCustomParameters({
      'tenant': '3663e35d-c7bc-4b90-90e0-a67a1d53bb77',
      'prompt': 'select_account',
    });

    final userCredential = await _auth.signInWithProvider(microsoftProvider);

    final banMessage = await _getBanMessage(userCredential.user?.email);
    if (banMessage != null) {
      await _auth.signOut();
      throw AuthBanException(banMessage);
    }

    if (userCredential.user != null) {
      String? accessToken;
      if (userCredential.credential != null) {
        final oauthCredential = userCredential.credential as dynamic;
        accessToken = oauthCredential.accessToken;
      } else {
        debugPrint("Usercredential is null");
      }

     
     

      // 1. Create user immediately without the photo URL
      final user = await _createOrUpdateUser(
        firebaseUser: userCredential.user!,
        principalName: userCredential.additionalUserInfo?.profile?['upn'] as String?,
      );
      
      final notificationService = NotificationService();

      // 2. Save new token for this user
      await notificationService.saveUserToken(user.uid, user.role.name);

      // 3. Load subscriptions only if student
      if (user.role == UserRole.student) {
        debugPrint('📥 Loading student subscriptions');
        await notificationService.loadSubscriptions(user.uid);
      } else {
        debugPrint('⏭️ Skipping subscription load (not a student)');
      }

      // 4. Fetch photo in background
      if (accessToken != null) {
        print('📸 AuthService: Preparing to pass access token: $accessToken');
        _graphService.getProfilePhotoUrl(
          accessToken: accessToken,
          userId: userCredential.user!.uid,
        ).then((photoUrl) {
          // ALWAYS update the photoUrl.
          // If photoUrl is not null, it sets the new photo.
          // If photoUrl IS null, this will clear any stale, old photo URL.
          _updateUserPhotoUrl(uid: userCredential.user!.uid, photoUrl: photoUrl);

        }).catchError((e){
          print('Failed to fetch and update profile photo in background: $e');
          // On error, we should also clear the photoUrl to be safe
          _updateUserPhotoUrl(uid: userCredential.user!.uid, photoUrl: null);
        });
      }
      
      return user;
    }
    return null;
  } on FirebaseAuthException catch (e) {
    if (e.code == 'web-context-cancelled') {
      print('Microsoft sign in cancelled by user.');
      return null;
    }
    rethrow;
  } catch (e) {
    throw Exception('Microsoft sign in failed: $e');
  }
}

// ✅ FIX: Enhanced signInWithEmailPassword for admin
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
      if (!_isSchoolEmail(email)) {
        final user = await _createOrUpdateUser(
          firebaseUser: userCredential.user!,
          isAdmin: true,
        );

        final notificationService = NotificationService();
        
        // Save token for admin (no subscriptions needed)
        await notificationService.saveUserToken(user.uid, user.role.name);
        
        return user;
      } else {
        await _auth.signOut();
        throw Exception('Invalid admin credentials');
      }
    }
    return null;
  } catch (e) {
    throw Exception('Email sign in failed: $e');
  }
}

  Future<String> _generateTeacherId() async {
  try {
    final counterRef = _database.ref('counters/teacherIdCounter');

    TransactionResult transactionResult;
    try {
      transactionResult = await counterRef.runTransaction((currentValue) {
        int nextId = 1;
        if (currentValue != null && currentValue is int) {
          nextId = currentValue + 1;
        }
        return Transaction.success(nextId);
      });
    } on FirebaseException catch (e, stack) {
      debugPrint('[AuthService] teacherId transaction failed: ${e.code} ${e.message}');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
    
    if (transactionResult.committed && transactionResult.snapshot.value != null) {
      final teacherNumber = transactionResult.snapshot.value as int;
      return 'Teacher_${teacherNumber.toString().padLeft(3, '0')}';
    } else {
      throw Exception('Failed to generate teacher ID');
    }
  } catch (e) {
    print('Error generating teacher ID: $e');
    // Fallback: use timestamp-based ID
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'Teacher_${timestamp.toString().substring(timestamp.toString().length - 6)}';
  }
}

  // Create or update user in Realtime Database
  Future<UserModel> _createOrUpdateUser({
  required User firebaseUser,
  String? principalName,
  String? photoUrl,
  bool isAdmin = false,
}) async {
  final String uid = firebaseUser.uid;
  final String email = firebaseUser.email ?? '';

  final banMessage = await _getBanMessage(email);
  if (!isAdmin && banMessage != null) {
    await _auth.signOut();
    throw AuthBanException(banMessage);
  }

  // Prioritize principalName for the displayName, with fallbacks
  final String displayName =
      principalName ?? firebaseUser.displayName ?? email.split('@')[0];

  // Determine role
  UserRole role;
  String? studentNumber;
  String? teacherID;

  if (isAdmin) {
  // ADDED: Check if the admin is a super_admin
  final superAdminRef = _database.ref('roles/super_admin/$uid');
  final superAdminSnap = await superAdminRef.get();
  
  if (superAdminSnap.exists) {
    role = UserRole.super_admin; // Correctly identify super_admin
  } else {
    // Check the admin role just in case, or default
    final adminRef = _database.ref('roles/admin/$uid');
    final adminSnap = await adminRef.get();
    if (adminSnap.exists) {
        role = UserRole.admin;
    } else {
        // This case might happen if DB rules are slow
        // or it's the very first login, default to admin
        role = UserRole.admin; 
    }
  }
  } else {
    final roleData = _determineRole(email);
    role = roleData['role'];
    studentNumber = roleData['studentNumber'];
  }

  Map<String, dynamic>? existingTeacherRoleData;
  if (role == UserRole.teacher) {
    final roleSnapshot = await _database.ref('roles/teacher/$uid').get();
    if (roleSnapshot.exists && roleSnapshot.value != null) {
      try {
        existingTeacherRoleData =
            Map<String, dynamic>.from(roleSnapshot.value as Map);
        teacherID = existingTeacherRoleData['teacherID'] as String? ?? teacherID;
      } catch (e) {
        debugPrint('Unable to parse teacher role data for $uid: $e');
      }
    }
  }

  // Check if user exists
  final userRef = _database.ref('users/$uid');
  final snapshot = await userRef.get();

  UserModel user;
  if (snapshot.exists) {
    // User exists: update their data
    final existingUser =
        UserModel.fromJson(Map<String, dynamic>.from(snapshot.value as Map));

    // Preserve existing teacherID for teachers
    if (role == UserRole.teacher) {
      teacherID = existingUser.teacherID ?? teacherID;
    }

    // Only update photoUrl if we have a new one, otherwise keep existing
    user = existingUser.copyWith(
      lastLogin: DateTime.now(),
      displayName: displayName,
      photoUrl: photoUrl ?? existingUser.photoUrl,
      teacherID: teacherID ?? existingUser.teacherID,
    );
  } else {
    if (role == UserRole.teacher) {
      teacherID ??= await _generateTeacherId();
    }
    
    // New user: create their data
    user = UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      role: role,
      studentNumber: studentNumber,
      teacherID: teacherID,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
      photoUrl: photoUrl,
    );
  }

  // Save the complete user object to the database
  try {
    await userRef.update(user.toJson());
  } on FirebaseException catch (e, stack) {
    debugPrint('[AuthService] users/$uid update failed: ${e.code} ${e.message}');
    debugPrintStack(stackTrace: stack);
    rethrow;
  }

  // Update role index - CRITICAL FIX: Use update() instead of set()
  final Map<String, dynamic> roleIndexData = {
    'email': email,
    'displayName': displayName,
  };

  if (role == UserRole.teacher) {
    // For teachers, only update these specific fields
    // Do NOT include rfid_uid, active_status, etc. - let ESP32 manage those
    if (teacherID != null) {
      roleIndexData['teacherID'] = teacherID;
    }

    if (existingTeacherRoleData != null) {
      roleIndexData.addAll(existingTeacherRoleData);
    }

    try {
      await _database.ref('roles/${role.name}/$uid').update(roleIndexData);
    } on FirebaseException catch (e, stack) {
      debugPrint('[AuthService] roles/${role.name}/$uid update failed: ${e.code} ${e.message}');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }

  } else if (role == UserRole.student) {
    roleIndexData['studentNumber'] = studentNumber;
    
    // For students, we can use set() since there's no ESP32 data
    try {
      await _database.ref('roles/${role.name}/$uid').set(roleIndexData);
    } on FirebaseException catch (e, stack) {
      debugPrint('[AuthService] roles/${role.name}/$uid set failed: ${e.code} ${e.message}');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  
  // ADD THIS BLOCK
  } else if (role == UserRole.admin || role == UserRole.super_admin) {
    // This was missing. Update the admin/super_admin role index too.
    // We use update() to be safe, just like the teacher logic.
    await _database.ref('roles/${role.name}/$uid').update(roleIndexData);
  }

  return user;
}

  // Update user's photo URL in the database
  Future<void> _updateUserPhotoUrl({
    required String uid,
    required String? photoUrl, // <-- 1. Change this to String?
  }) async {
    try {
      // Update the user's photoUrl in the database
      // Setting photoUrl to null here will remove it from Firebase
      await _database.ref('users/$uid/photoUrl').set(photoUrl); // <-- 2. This now accepts null

      if (photoUrl != null && photoUrl.isNotEmpty) {
        print('Successfully updated user photo URL for $uid');
      } else {
        print('Successfully cleared stale photo URL for $uid');
      }
    } catch (e) {
      print('Failed to update user photo URL: $e');
    }
  }

  // Determine role from email
  Map<String, dynamic> _determineRole(String email) {
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

    // Default to teacher if not school email
    return {'role': UserRole.teacher, 'studentNumber': null};
  }

  // Check if email is from school domain
  bool _isSchoolEmail(String email) {
    return email.endsWith('@malolos.sti.edu.ph');
  }

  // Sign out
  Future<void> signOut() async {
  if (currentUser != null) {
    debugPrint('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓');
    debugPrint('👋 SIGNING OUT user: ${currentUser!.uid}');
    
    final notificationService = NotificationService();
    
    // Clear all tokens and subscriptions for this user
    await notificationService.clearUserToken(currentUser!.uid);
  }

  await _auth.signOut();
}

  // Get current user
  User? get currentUser => _auth.currentUser;
}