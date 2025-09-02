import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/services/microsoft_graph_service.dart';

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

  // Microsoft Sign In (for teachers and students)
  Future<UserModel?> signInWithMicrosoft() async {
    try {
      final microsoftProvider = MicrosoftAuthProvider();
      microsoftProvider.setCustomParameters({
        'tenant': '3663e35d-c7bc-4b90-90e0-a67a1d53bb77',
        'prompt': 'select_account'
      });

      final userCredential = await _auth.signInWithProvider(microsoftProvider);

      if (userCredential.user != null) {
       String? accessToken;
         if (userCredential.credential != null) {
          // Cast the generic AuthCredential to the specific OAuthCredential
          // to make the accessToken property available.
          final oauthCredential = userCredential.credential as dynamic;
          accessToken = oauthCredential.accessToken;
          debugPrint("✅ Successfully extracted access token!");
        } else {
          debugPrint("❌ userCredential.credential was null.");
        }

        // 1. Create user immediately without the photo URL. This is fast.
        final user = await _createOrUpdateUser(
          firebaseUser: userCredential.user!,
          principalName: userCredential.additionalUserInfo?.profile?['upn'] as String?,
        );

        // 2. Fetch the photo in the background. Don't await it.
        if (accessToken != null) {
          print('🔑 AuthService: Preparing to pass access token: $accessToken');
          _graphService.getProfilePhotoUrl(
            accessToken: accessToken,
            userId: userCredential.user!.uid,
          ).then((photoUrl) {
            if (photoUrl != null) {
              // 3. Once fetched, update the user's profile in the database.
              _updateUserPhotoUrl(uid: userCredential.user!.uid, photoUrl: photoUrl);
            }
          }).catchError((e){
             print('Failed to fetch and update profile photo in background: $e');
          });
        }
        
        return user; // Return the user immediately.
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
          return await _createOrUpdateUser(
            firebaseUser: userCredential.user!,
            isAdmin: true,
          );
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
  Future<UserModel> _createOrUpdateUser({
    required User firebaseUser,
    String? principalName,
    String? photoUrl,
    bool isAdmin = false,
  }) async {
    final String uid = firebaseUser.uid;
    final String email = firebaseUser.email ?? '';

    // Prioritize principalName for the displayName, with fallbacks
    final String displayName =
        principalName ?? firebaseUser.displayName ?? email.split('@')[0];

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
      // User exists: update their data
      final existingUser =
          UserModel.fromJson(Map<String, dynamic>.from(snapshot.value as Map));

      // Only update photoUrl if we have a new one, otherwise keep existing
      user = existingUser.copyWith(
        lastLogin: DateTime.now(),
        displayName: displayName,
        photoUrl: photoUrl ?? existingUser.photoUrl,
      );
    } else {
      // New user: create their data
      user = UserModel(
        uid: uid,
        email: email,
        displayName: displayName,
        role: role,
        studentNumber: studentNumber,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        photoUrl: photoUrl,
      );
    }

    // Save the complete user object to the database
    await userRef.set(user.toJson());

    // Update role index
    final Map<String, dynamic> roleIndexData = {
      'email': email,
      'displayName': displayName,
    };

    if (role == UserRole.teacher) {
      roleIndexData['rfid_uid'] = null;
      roleIndexData['active_status'] = "offline";
      roleIndexData['teacher_msg'] = null;
    } else if (role == UserRole.student) {
      roleIndexData['studentNumber'] = studentNumber;
    } 

    // Write the index data to the database
    if (role != UserRole.admin) {
      await _database.ref('roles/${role.name}/$uid').set(roleIndexData);
    }

    return user;
  }

  // Update user's photo URL in the database
  Future<void> _updateUserPhotoUrl({
    required String uid,
    required String photoUrl,
  }) async {
    try {
      // Update the user's photoUrl in the database
      await _database.ref('users/$uid/photoUrl').set(photoUrl);
      
      print('Successfully updated user photo URL for $uid');
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
    await _auth.signOut();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;
}