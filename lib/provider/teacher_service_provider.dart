// provider/teacher_service_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/services/teacher_service.dart';

// Provider for TeacherService
final teacherServiceProvider = Provider<TeacherService>((ref) {
  final database = ref.watch(firebaseDatabaseProvider);
  return TeacherService(database: database);
});

// Stream provider for teacher status
final teacherStatusProvider = StreamProvider.family<String, String>((ref, teacherUid) {
  final teacherService = ref.watch(teacherServiceProvider);
  return teacherService.getTeacherStatus(teacherUid);
});

// Stream provider for teacher note
final teacherNoteProvider = StreamProvider.family<String?, String>((ref, teacherUid) {
  final teacherService = ref.watch(teacherServiceProvider);
  return teacherService.getTeacherNote(teacherUid);
});