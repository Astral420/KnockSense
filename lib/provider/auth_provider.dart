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
      if (user == null) { return Stream.value(null); }

      final db = ref.read(firebaseDatabaseProvider);
      return db.ref('users/${user.uid}').onValue.map((event) {
        if (event.snapshot.exists) {
          return UserModel.fromJson(
            Map<String, dynamic>.from(event.snapshot.value as Map),
          );
        }
        return null;
      });
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});




// Update authServiceProvider to include GraphService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    auth: ref.read(firebaseAuthProvider),
    database: ref.read(firebaseDatabaseProvider),
    graphService: ref.read(graphServiceProvider),
  );
});