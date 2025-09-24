import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/appointment_model.dart';
import 'package:knocksense/services/appointment_service.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/models/teacher_model.dart';

// Date Range provider (moved here to avoid duplication)
final dateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

// Appointment service provider
final appointmentServiceProvider = Provider<AppointmentService>((ref) {
  final database = ref.watch(firebaseDatabaseProvider);
  return AppointmentService(database: database);
});

// Stream provider for student's appointments
final studentAppointmentsProvider = StreamProvider<List<AppointmentModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  final appointmentService = ref.watch(appointmentServiceProvider);
  
  return user.when(
    data: (userData) {
      if (userData == null || userData.studentNumber == null) {
        return Stream.value([]);
      }
      return appointmentService.getStudentAppointments(userData.studentNumber!);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// Stream provider for teacher's pending appointments
final teacherPendingAppointmentsProvider = StreamProvider<List<AppointmentModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  final appointmentService = ref.watch(appointmentServiceProvider);
  
  return user.when(
    data: (userData) {
      if (userData == null || userData.role != UserRole.teacher) {
        return Stream.value([]);
      }
      return appointmentService.getTeacherPendingAppointments(userData.uid);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// NEW: Stream provider for teacher's active appointments (pending + accepted in waiting/meeting states)
final teacherActiveAppointmentsProvider = StreamProvider<List<AppointmentModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  final appointmentService = ref.watch(appointmentServiceProvider);
  
  return user.when(
    data: (userData) {
      if (userData == null || userData.role != UserRole.teacher) {
        return Stream.value([]);
      }
      return appointmentService.getTeacherActiveAppointments(userData.uid);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// Stream provider for teacher's all appointments
final teacherAllAppointmentsProvider = StreamProvider<List<AppointmentModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  final appointmentService = ref.watch(appointmentServiceProvider);
  
  return user.when(
    data: (userData) {
      if (userData == null || userData.role != UserRole.teacher) {
        return Stream.value([]);
      }
      return appointmentService.getTeacherAllAppointments(userData.uid);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// Provider to check if student has pending appointment with specific teacher
final hasPendingAppointmentProvider = FutureProvider.family<bool, String>((ref, teacherUid) async {
  final user = ref.watch(currentUserProvider);
  final appointmentService = ref.watch(appointmentServiceProvider);
  
  return user.when(
    data: (userData) async {
      if (userData == null || userData.studentNumber == null) {
        return false;
      }
      return await appointmentService.hasPendingAppointment(
        studentNumber: userData.studentNumber!,
        teacherUid: teacherUid,
      );
    },
    loading: () => false,
    error: (_, __) => false,
  );
});

// Notifier for handling appointment actions
class AppointmentNotifier extends StateNotifier<AsyncValue<void>> {
  final AppointmentService _service;
  
  AppointmentNotifier(this._service) : super(const AsyncValue.data(null));
  
  Future<Map<String, dynamic>?> createAppointment({
    required UserModel student,
    required TeacherModel teacher,
    String? studentNote,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final appointmentId = await _service.createAppointment(
        student: student,
        teacher: teacher,
        studentNote: studentNote,
      );
      
      state = const AsyncValue.data(null);
      return appointmentId;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
  
  Future<bool> respondToAppointment({
    required String studentNumber,
    required String appointmentId,
    required String teacherUid,
    required TeacherAction action,
    String? teacherResponse,
    DateTime? scheduledTime,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final success = await _service.respondToAppointment(
        studentNumber: studentNumber,
        appointmentId: appointmentId,
        teacherUid: teacherUid,
        action: action,
        teacherResponse: teacherResponse,
        scheduledTime: scheduledTime,
      );
      
      state = const AsyncValue.data(null);
      return success;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
  
  Future<bool> cancelAppointment({
    required String studentNumber,
    required String appointmentId,
    required String teacherUid,
    String ? reason,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final success = await _service.cancelAppointment(
        studentNumber: studentNumber,
        appointmentId: appointmentId,
        teacherUid: teacherUid,
        reason: reason,
      );
      
      state = const AsyncValue.data(null);
      return success;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
  
  Future<bool> completeAppointment({
    required String studentNumber,
    required String appointmentId,
    required String teacherUid,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final success = await _service.completeAppointment(
        studentNumber: studentNumber,
        appointmentId: appointmentId,
        teacherUid: teacherUid,
      );
      
      state = const AsyncValue.data(null);
      return success;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

// Provider for appointment actions
final appointmentNotifierProvider = StateNotifierProvider<AppointmentNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(appointmentServiceProvider);
  return AppointmentNotifier(service);
});


// ======== NEWLY ADDED PROVIDER ========
// Filtered appointment history for teachers, mirroring the student's logic.
final filteredTeacherHistoryProvider = Provider<List<AppointmentModel>>((ref) {
  final appointments = ref.watch(teacherAllAppointmentsProvider);
  final dateRange = ref.watch(dateRangeProvider);

  return appointments.when(
    data: (appointmentList) {
      if (dateRange == null) return appointmentList;

      final startOfDay = DateTime(
        dateRange.start.year,
        dateRange.start.month,
        dateRange.start.day,
        0, 0, 0, 0, 0
      );

      final endOfDay = DateTime(
        dateRange.end.year,
        dateRange.end.month,
        dateRange.end.day,
        23, 59, 59, 999, 999
      );

      final filtered = appointmentList.where((appointment) {
        final appointmentDate = appointment.createdAt;
        final isInRange = appointmentDate.isAtSameMomentAs(startOfDay) ||
                         appointmentDate.isAtSameMomentAs(endOfDay) ||
                         (appointmentDate.isAfter(startOfDay) && appointmentDate.isBefore(endOfDay));
        return isInRange;
      }).toList();

      return filtered;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});