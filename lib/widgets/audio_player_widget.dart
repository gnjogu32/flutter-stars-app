import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/screen_awake_controller.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;

  const AudioPlayerWidget({super.key, required this.audioUrl});

  @override
  State<AudioPlayerWidget> createState() => AudioPlayerWidgetState();
}

class AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _init();
    _player.playerStateStream.listen((state) {
      if (state.playing) {
        ScreenAwakeController.acquire();
      } else {
        ScreenAwakeController.release();
      }
    });
  }

  void pause() {
    if (_player.playing) {
      _player.pause();
    }
  }

  Future<void> _init() async {
    try {
      await _player.setUrl(widget.audioUrl);
    } catch (e) {
      debugPrint("Error loading audio: $e");
    }
  }

  @override
  void dispose() {
    if (_player.playing) {
      ScreenAwakeController.release();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snapshot) {
              final playerState = snapshot.data;
              final processingState = playerState?.processingState;
              final playing = playerState?.playing;
              if (processingState == ProcessingState.loading ||
                  processingState == ProcessingState.buffering) {
                return const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              } else if (playing != true) {
                return IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: _player.play,
                );
              } else if (processingState != ProcessingState.completed) {
                return IconButton(
                  icon: const Icon(Icons.pause),
                  onPressed: _player.pause,
                );
              } else {
                return IconButton(
                  icon: const Icon(Icons.replay),
                  onPressed: () => _player.seek(Duration.zero),
                );
              }
            },
          ),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = _player.duration ?? Duration.zero;
                return Column(
                  children: [
                    Slider(
                      value: position.inMilliseconds.toDouble(),
                      max: duration.inMilliseconds.toDouble(),
                      onChanged: (value) {
                        _player.seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(position), style: Theme.of(context).textTheme.bodySmall),
                          Text(_formatDuration(duration), style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
