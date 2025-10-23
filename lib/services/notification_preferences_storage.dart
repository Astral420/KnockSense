import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:knocksense/models/notification_preferences.dart';

class NotificationPreferencesStorage {
  static const _keyPrefix = 'notif_pref_';

  static Future<NotificationPreferenceState> loadForUid(
    String uid, {
    SharedPreferences? prefs,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final raw = resolvedPrefs.getString(_key(uid));
    if (raw == null) {
      return NotificationPreferenceState.defaults;
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return NotificationPreferenceState(
        vibrateEnabled: data['vibrate'] as bool? ?? true,
        soundEnabled: data['sound'] as bool? ?? true,
      );
    } catch (_) {
      return NotificationPreferenceState.defaults;
    }
  }

  static Future<void> saveForUid(
    String uid,
    NotificationPreferenceState state, {
    SharedPreferences? prefs,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    await resolvedPrefs.setString(
      _key(uid),
      jsonEncode({
        'vibrate': state.vibrateEnabled,
        'sound': state.soundEnabled,
      }),
    );
  }

  static Future<void> clearForUid(String uid, {SharedPreferences? prefs}) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    await resolvedPrefs.remove(_key(uid));
  }

  static String _key(String uid) => '$_keyPrefix$uid';
}
