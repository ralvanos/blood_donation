/// Pure helpers for PIN auto-lock timeout behavior (testable without Flutter bindings).
class AutoLockPolicy {
  AutoLockPolicy._();

  /// Allowed timeout values in seconds (0 = lock immediately on pause).
  static const List<int> allowedTimeoutSeconds = [0, 30, 60, 300];

  static const int defaultTimeoutSeconds = 0;

  static bool isAllowedTimeout(int seconds) =>
      allowedTimeoutSeconds.contains(seconds);

  /// Normalize unknown/corrupt prefs to the default (immediate).
  static int normalizeTimeout(int? seconds) {
    if (seconds == null || !isAllowedTimeout(seconds)) {
      return defaultTimeoutSeconds;
    }
    return seconds;
  }

  /// When true, lock as soon as the app is paused (legacy / "Immediately").
  static bool lockImmediatelyOnPause(int timeoutSeconds) =>
      normalizeTimeout(timeoutSeconds) <= 0;

  /// Whether resume should require PIN after a background period.
  ///
  /// For immediate timeout, locking already happened on pause — this returns
  /// false so we do not double-handle. Callers that already locked on pause
  /// leave [_unlocked] false.
  static bool shouldLockOnResume({
    required int timeoutSeconds,
    required DateTime? pausedAt,
    required DateTime now,
  }) {
    final timeout = normalizeTimeout(timeoutSeconds);
    if (timeout <= 0) return false;
    if (pausedAt == null) return false;
    final elapsed = now.difference(pausedAt);
    if (elapsed.isNegative) return false;
    return elapsed >= Duration(seconds: timeout);
  }

  static String labelForTimeout(int seconds) {
    switch (normalizeTimeout(seconds)) {
      case 30:
        return 'After 30 seconds';
      case 60:
        return 'After 1 minute';
      case 300:
        return 'After 5 minutes';
      case 0:
      default:
        return 'Immediately';
    }
  }
}
