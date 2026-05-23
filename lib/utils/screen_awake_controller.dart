import 'package:flutter/foundation.dart';

/// Keeps the screen awake while at least one media player is actively playing.
class ScreenAwakeController {
  ScreenAwakeController._();

  static int _activePlaybackHolders = 0;
  static bool _isEnabled = false;
  static bool _syncInProgress = false;

  static void acquire() {
    _activePlaybackHolders += 1;
    _scheduleSync();
  }

  static void release() {
    if (_activePlaybackHolders > 0) {
      _activePlaybackHolders -= 1;
      _scheduleSync();
    }
  }

  static void _scheduleSync() {
    if (_syncInProgress) return;
    _syncInProgress = true;

    () async {
      try {
        final shouldEnable = _activePlaybackHolders > 0;
        if (shouldEnable == _isEnabled) return;

        // WakelockPlus.toggle removed for AGP 9+ compatibility
        _isEnabled = shouldEnable;
      } catch (e) {
        debugPrint('Wakelock toggle failed: $e');
      } finally {
        _syncInProgress = false;
        // If state changed while syncing, run once more.
        final shouldEnable = _activePlaybackHolders > 0;
        if (shouldEnable != _isEnabled) {
          _scheduleSync();
        }
      }
    }();
  }
}
