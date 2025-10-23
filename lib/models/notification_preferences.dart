class NotificationPreferenceState {
  final bool vibrateEnabled;
  final bool soundEnabled;

  const NotificationPreferenceState({
    required this.vibrateEnabled,
    required this.soundEnabled,
  });

  static const NotificationPreferenceState defaults =
      NotificationPreferenceState(vibrateEnabled: true, soundEnabled: true);

  NotificationPreferenceState copyWith({
    bool? vibrateEnabled,
    bool? soundEnabled,
  }) {
    return NotificationPreferenceState(
      vibrateEnabled: vibrateEnabled ?? this.vibrateEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }
}
