
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/services/microsoft_graph_service.dart'; 

// Provider for the FirebaseStorage instance
final firebaseStorageProvider =
    Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

// Provider for our GraphService
final graphServiceProvider = Provider<GraphService>((ref) {
  // The Dio dependency is no longer needed here
  return GraphService(
    storage: ref.watch(firebaseStorageProvider),
  );
});
