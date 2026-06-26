import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/provider/auth_provider.dart';

class AdminPermissions {
  final bool changeWifiInformation;
  final bool removeTeacherAccounts;
  final bool seeAccessLogs;
  final bool seeAttendanceLogs;

  const AdminPermissions({
    this.changeWifiInformation = false,
    this.removeTeacherAccounts = false,
    this.seeAccessLogs = false,
    this.seeAttendanceLogs = false,
  });

  factory AdminPermissions.fromMap(Map<dynamic, dynamic> map) {
    bool readBool(String key) {
      final value = map[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
      }
      return false;
    }

    return AdminPermissions(
      changeWifiInformation: readBool('changeWifiInformation'),
      removeTeacherAccounts: readBool('removeTeacherAccounts'),
      seeAccessLogs: readBool('seeAccessLogs'),
      seeAttendanceLogs: readBool('seeAttendanceLogs'),
    );
  }
}

const AdminPermissions _superAdminPermissions = AdminPermissions(
  changeWifiInformation: true,
  removeTeacherAccounts: true,
  seeAccessLogs: true,
  seeAttendanceLogs: true,
);

final adminPermissionsProvider = StreamProvider<AdminPermissions>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  final database = ref.watch(firebaseDatabaseProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) {
        return Stream.value(const AdminPermissions());
      }

      if (user.role == UserRole.super_admin) {
        return Stream.value(_superAdminPermissions);
      }

      if (user.role != UserRole.admin) {
        return Stream.value(const AdminPermissions());
      }

      final refPath = database.ref('roles/admin/${user.uid}/permissions');
      return refPath.onValue.map((event) {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          return const AdminPermissions();
        }
        final raw = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        return AdminPermissions.fromMap(raw);
      });
    },
    loading: () => Stream.value(const AdminPermissions()),
    error: (_, __) => Stream.value(const AdminPermissions()),
  );
});
