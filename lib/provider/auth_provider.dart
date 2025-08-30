import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/user_models.dart';
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

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) async {
      if (user == null) return null;

      final db = ref.read(firebaseDatabaseProvider);
      final snapshot = await db.ref('users/${user.uid}').get();

      if (snapshot.exists) {
        return UserModel.fromJson(
          Map<String, dynamic>.from(snapshot.value as Map),
        );
      }
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    auth: ref.read(firebaseAuthProvider),
    database: ref.read(firebaseDatabaseProvider),
  );
});
