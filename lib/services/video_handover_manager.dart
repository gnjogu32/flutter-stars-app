import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Centralized manager for seamless video controller caching, preloading,
/// and smooth handovers across feed, reels, and full-screen players.
class VideoHandoverManager {
  static final VideoHandoverManager _instance =
      VideoHandoverManager._internal();
  factory VideoHandoverManager() => _instance;
  VideoHandoverManager._internal();

  static const int _maxCachedControllers = 8;
  final Map<String, VideoPlayerController> _activeControllers = {};
  final List<String> _lruKeys = [];

  /// Register a controller for handover or pre-caching under a key (e.g. postId or videoUrl).
  void registerHandover(String key, VideoPlayerController controller) {
    if (key.isEmpty) return;
    _activeControllers[key] = controller;
    _updateLru(key);
    _trimCache();
  }

  /// Retrieve an active controller by key without removing it.
  VideoPlayerController? get(String key) {
    if (key.isEmpty) return null;
    final controller = _activeControllers[key];
    if (controller != null) {
      _updateLru(key);
    }
    return controller;
  }

  /// Get and remove controller from the handover map (transferring ownership).
  VideoPlayerController? getAndRemove(String key) {
    if (key.isEmpty) return null;
    _lruKeys.remove(key);
    return _activeControllers.remove(key);
  }

  /// Get an existing controller or create and initialize a new controller for the given URL.
  Future<VideoPlayerController> getOrCreateController(
    String key,
    String videoUrl, {
    bool autoInitialize = true,
  }) async {
    final effectiveKey = key.isNotEmpty ? key : videoUrl;
    final existing = get(effectiveKey);
    if (existing != null) {
      return existing;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _activeControllers[effectiveKey] = controller;
    _updateLru(effectiveKey);
    _trimCache();

    if (autoInitialize && !controller.value.isInitialized) {
      try {
        await controller.initialize();
        await controller.setLooping(true);
      } catch (e) {
        debugPrint('Error initializing controller for $effectiveKey: $e');
      }
    }

    return controller;
  }

  void _updateLru(String key) {
    _lruKeys.remove(key);
    _lruKeys.add(key);
  }

  void _trimCache() {
    while (_activeControllers.length > _maxCachedControllers) {
      if (_lruKeys.isEmpty) break;
      final oldestKey = _lruKeys.removeAt(0);
      final controller = _activeControllers.remove(oldestKey);
      controller?.pause();
      controller?.dispose();
    }
  }

  /// Dispose of all cached controllers.
  void disposeAll() {
    for (final controller in _activeControllers.values) {
      controller.pause();
      controller.dispose();
    }
    _activeControllers.clear();
    _lruKeys.clear();
  }
}
