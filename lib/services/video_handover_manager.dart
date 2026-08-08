import 'package:video_player/video_player.dart';

class VideoHandoverManager {
  static final VideoHandoverManager _instance =
      VideoHandoverManager._internal();
  factory VideoHandoverManager() => _instance;
  VideoHandoverManager._internal();

  final Map<String, VideoPlayerController> _activeControllers = {};

  void registerHandover(String postId, VideoPlayerController controller) {
    _activeControllers[postId] = controller;
  }

  VideoPlayerController? getAndRemove(String postId) {
    return _activeControllers.remove(postId);
  }

  void disposeAll() {
    for (final controller in _activeControllers.values) {
      controller.dispose();
    }
    _activeControllers.clear();
  }
}
