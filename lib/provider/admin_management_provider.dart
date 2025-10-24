import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/services/admin_teacher_service.dart';

final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instanceFor(region: 'asia-southeast1');
});

final adminTeacherServiceProvider = Provider<AdminTeacherService>((ref) {
  return AdminTeacherService(functions: ref.read(firebaseFunctionsProvider));
});
