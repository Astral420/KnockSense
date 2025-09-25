// provider/teacher_service_provider.dart

import 'dart:async';
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

// NEW: Stream provider for manual unlock status
final manualUnlockStatusProvider = StreamProvider.family<String?, String>((ref, teacherUid) {
  final teacherService = ref.watch(teacherServiceProvider);
  return teacherService.getManualUnlockStatus(teacherUid);
});

// NEW: Provider for handling manual door unlock
final manualDoorUnlockProvider = StateNotifierProvider<ManualUnlockNotifier, AsyncValue<bool>>((ref) {
  final teacherService = ref.watch(teacherServiceProvider);
  return ManualUnlockNotifier(teacherService);
});

// NEW: State notifier for manual door unlock operations
class ManualUnlockNotifier extends StateNotifier<AsyncValue<bool>> {
  final TeacherService _teacherService;

  ManualUnlockNotifier(this._teacherService) : super(const AsyncValue.data(false));

  Future<void> requestUnlock(String teacherUid, String teacherName, String teacherID) async {
    state = const AsyncValue.loading();
    
    try {
      final success = await _teacherService.requestManualDoorUnlock(teacherUid, teacherName, teacherID);
      state = AsyncValue.data(success);
      
      // Reset state after 5 seconds
      Timer(const Duration(seconds: 5), () {
        if (mounted) {
          state = const AsyncValue.data(false);
        }
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      
      // Reset state after error
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          state = const AsyncValue.data(false);
        }
      });
    }
  }
}

final teacherStatusWithDurationProvider = StateNotifierProvider.family
    .autoDispose<TeacherStatusNotifier, AsyncValue<TeacherStatusData?>, String>(
        (ref, teacherUid) {
  final teacherService = ref.watch(teacherServiceProvider);
  return TeacherStatusNotifier(teacherService, teacherUid);
});

class RealTimeTeacherStatusData extends TeacherStatusData {
  RealTimeTeacherStatusData({
    required String status,
    DateTime? changedAt,
  }) : super(status: status, changedAt: changedAt);
  
  @override
  String get duration {
    // Always calculate duration in real-time when accessed
    return TeacherService.calculateDurationRealTime(changedAt);
  }
}

class TeacherStatusNotifier extends StateNotifier<AsyncValue<TeacherStatusData?>> {
  final TeacherService _teacherService;
  final String _teacherUid;
  StreamSubscription? _firebaseSubscription;
  Timer? _periodicTimer;

  TeacherStatusNotifier(this._teacherService, this._teacherUid)
      : super(const AsyncValue.loading()) {
    _listenToFirebase();
  }

  void _listenToFirebase() {
    // Listen to the stream from your service
    _firebaseSubscription =
        _teacherService.getTeacherStatusWithDuration(_teacherUid).listen(
      (statusData) {
        // When new data arrives from Firebase:

        // 1. Cancel any old refresh timer that might be running.
        _periodicTimer?.cancel();
        
        // 2. Immediately update the state with the fresh data.
        state = AsyncValue.data(statusData);

        // 3. Start a new 5-second timer to handle periodic refreshes.
        _periodicTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          // Every 5 seconds, update the state again.
          // We create a new object to ensure Riverpod detects the change and rebuilds the UI.
          state = AsyncValue.data(RealTimeTeacherStatusData(
            status: statusData.status,
            changedAt: statusData.changedAt,
          ));
        });
      },
      onError: (error, stackTrace) {
        state = AsyncValue.error(error, stackTrace);
      },
    );
  }

  // Clean up the listeners when the provider is disposed
  @override
  void dispose() {
    _firebaseSubscription?.cancel();
    _periodicTimer?.cancel();
    super.dispose();
  }
}