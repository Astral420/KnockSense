import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/provider/graph_provider.dart';
import 'package:knocksense/services/auth_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firebaseDatabaseProvider = Provider<FirebaseDatabase>(
  (ref) => FirebaseDatabase.instance,
);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(firebaseAuthProvider).authStateChanges();
});



// Make currentUserProvider a StreamProvider to listen to real-time updates
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(null);
      }

      final db = ref.read(firebaseDatabaseProvider);
      
      // Add error handling and retry logic
      return db.ref('users/${user.uid}').onValue
        .map((event) {
          if (event.snapshot.exists && event.snapshot.value != null) {
            try {
              return UserModel.fromJson(
                Map<String, dynamic>.from(event.snapshot.value as Map),
              );
            } catch (e) {
              print('Error parsing user model: $e');
              // Return null instead of throwing to prevent UI crashes
              return null;
            }
          }
          return null;
        })
        .handleError((error) {
          print('Stream error in currentUserProvider: $error');
          // Don't throw the error, return null instead
          return null;
        });
    },
    loading: () => Stream.value(null),
    error: (error, stack) {
      print('Auth state error: $error');
      return Stream.value(null);
    },
  );
});

// Add a separate provider for user that doesn't fail on errors
final safeCurrentUserProvider = Provider<UserModel?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.asData?.value;
});

// Also add this helper provider to check auth status
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.asData?.value != null;
});


// Update authServiceProvider to include GraphService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    auth: ref.read(firebaseAuthProvider),
    database: ref.read(firebaseDatabaseProvider),
    graphService: ref.read(graphServiceProvider),
  );
});

