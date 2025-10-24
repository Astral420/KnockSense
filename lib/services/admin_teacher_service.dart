import 'package:cloud_functions/cloud_functions.dart';

class AdminTeacherService {
  final FirebaseFunctions _functions;

  AdminTeacherService({required FirebaseFunctions functions})
      : _functions = functions;

  Future<String?> deleteTeacherAccount({
    required String teacherUid,
    required String deletedBy,
  }) async {
    try {
      final callable = _functions.httpsCallable('deleteTeacherAccount');
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
        message: e.message ?? 'Failed to delete teacher account.',
      );
    } catch (e) {
      throw AdminTeacherDeletionException(
        code: 'unknown',
        message: 'Failed to delete teacher account: $e',
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
