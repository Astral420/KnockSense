import 'package:cloud_functions/cloud_functions.dart';

class AdminTeacherService {
  final FirebaseFunctions _functions;

  AdminTeacherService({required FirebaseFunctions functions})
      : _functions = functions;

  Future<String?> archiveTeacherAccount({
    required String teacherUid,
    required String archivedBy,
    String? reason,
  }) async {
    try {
      final callable = _functions.httpsCallable('archiveTeacherAccount');
      final response = await callable.call({
        'teacherUid': teacherUid,
        'deletedBy': archivedBy,
        if (reason != null) 'reason': reason,
      });

      final data = response.data;
      if (data is Map) {
        try {
          final map = Map<String, dynamic>.from(data);
          return map['message'] as String?;
        } catch (_) {
          return null;
        }
      }
      if (data is String) {
        return data;
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      throw AdminTeacherDeletionException(
        code: e.code,
        message: e.message ?? 'Failed to archive teacher account.',
      );
    } catch (e) {
      throw AdminTeacherDeletionException(
        code: 'unknown',
        message: 'Failed to archive teacher account: $e',
      );
    }
  }

  Future<String?> hardDeleteTeacherAccount({
    required String teacherUid,
    required String deletedBy,
  }) async {
    try {
      final callable = _functions.httpsCallable('hardDeleteTeacherAccount');
      final response = await callable.call({
        'teacherUid': teacherUid,
        'deletedBy': deletedBy,
      });

      final data = response.data;
      if (data is Map) {
        try {
          final map = Map<String, dynamic>.from(data);
          return map['message'] as String?;
        } catch (_) {
          return null;
        }
      }
      if (data is String) {
        return data;
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      throw AdminTeacherDeletionException(
        code: e.code,
        message: e.message ?? 'Failed to hard delete teacher account.',
      );
    } catch (e) {
      throw AdminTeacherDeletionException(
        code: 'unknown',
        message: 'Failed to hard delete teacher account: $e',
      );
    }
  }
}

class AdminTeacherDeletionException implements Exception {
  final String code;
  final String message;

  AdminTeacherDeletionException({required this.code, required this.message});

  @override
  String toString() => 'AdminTeacherDeletionException($code, $message)';
}
