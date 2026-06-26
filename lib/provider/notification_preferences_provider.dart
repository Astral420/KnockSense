import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:knocksense/models/notification_preferences.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/services/notification_preferences_storage.dart';
import 'package:knocksense/services/notification_service.dart';

class NotificationPreferencesController
    extends StateNotifier<AsyncValue<NotificationPreferenceState>> {
  NotificationPreferencesController(this._ref)
      : super(const AsyncValue.loading()) {
    _subscription = _ref.listen<UserModel?>(
      safeCurrentUserProvider,
      (previous, next) {
        if (previous?.uid != next?.uid) {
          _handleUserChanged(next);
        }
      },
    );
    _initialize();
  }

  final Ref _ref;
  SharedPreferences? _prefs;
  NotificationPreferenceState _cached =
      NotificationPreferenceState.defaults;
  ProviderSubscription<UserModel?>? _subscription;
  final NotificationService _notificationService = NotificationService();

  Future<void> _initialize() async {
    try {
      final prefs = await _ensurePrefs();
      final user = _ref.read(safeCurrentUserProvider);
      if (user == null) {
        _cached = NotificationPreferenceState.defaults;
        state = const AsyncValue.data(NotificationPreferenceState.defaults);
        await _notificationService.applyPreferences(
          NotificationPreferenceState.defaults,
        );
        return;
      }
      final stored = await NotificationPreferencesStorage.loadForUid(
        user.uid,
        prefs: prefs,
      );
      _cached = stored;
      state = AsyncValue.data(stored);
      await _notificationService.applyPreferences(stored);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<SharedPreferences> _ensurePrefs() async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> _handleUserChanged(UserModel? user) async {
    if (state.isLoading) return;
    if (user == null) {
      _cached = NotificationPreferenceState.defaults;
      state = const AsyncValue.data(NotificationPreferenceState.defaults);
      await _notificationService.applyPreferences(
        NotificationPreferenceState.defaults,
      );
      return;
    }
    final prefs = await _ensurePrefs();
    final stored = await NotificationPreferencesStorage.loadForUid(
      user.uid,
      prefs: prefs,
    );
    _cached = stored;
    state = AsyncValue.data(stored);
    await _notificationService.applyPreferences(stored);
  }

  Future<void> refresh() async {
    final user = _ref.read(safeCurrentUserProvider);
    final prefs = await _ensurePrefs();
    if (user == null) {
      _cached = NotificationPreferenceState.defaults;
      state = const AsyncValue.data(NotificationPreferenceState.defaults);
      await _notificationService.applyPreferences(
        NotificationPreferenceState.defaults,
      );
      return;
    }
    final loaded = await NotificationPreferencesStorage.loadForUid(
      user.uid,
      prefs: prefs,
    );
    _cached = loaded;
    state = AsyncValue.data(loaded);
    await _notificationService.applyPreferences(loaded);
  }

  Future<void> setVibrate(bool enabled) async {
    await _update((current) => current.copyWith(vibrateEnabled: enabled));
  }

  Future<void> setSound(bool enabled) async {
    await _update((current) => current.copyWith(soundEnabled: enabled));
  }

  Future<void> _update(
    NotificationPreferenceState Function(NotificationPreferenceState) modify,
  ) async {
    final current = state.value ?? _cached;
    final updated = modify(current);
    _cached = updated;
    state = AsyncValue.data(updated);
    final user = _ref.read(safeCurrentUserProvider);
    if (user == null) {
      await _notificationService.applyPreferences(updated);
      return;
    }
    final prefs = await _ensurePrefs();
    await NotificationPreferencesStorage.saveForUid(
      user.uid,
      updated,
      prefs: prefs,
    );
    await _notificationService.saveRemotePreferences(user.uid, updated);
    await _notificationService.applyPreferences(updated);
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }
}

final notificationPreferencesControllerProvider =
    StateNotifierProvider<NotificationPreferencesController,
        AsyncValue<NotificationPreferenceState>>(
  (ref) => NotificationPreferencesController(ref),
);
