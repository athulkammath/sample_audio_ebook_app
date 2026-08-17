import 'package:audio_ebook_library/core/services/audio_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_screenshot/no_screenshot.dart';

class AudioPlayerPage extends ConsumerStatefulWidget {
  final String audioAssetPath;
  final String title;

  const AudioPlayerPage({
    super.key,
    required this.audioAssetPath,
    required this.title,
  });

  @override
  ConsumerState<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends ConsumerState<AudioPlayerPage> {
  final NoScreenshot _noScreenshot = NoScreenshot.instance;

  @override
  void initState() {
    super.initState();
    _noScreenshot.screenshotOff();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    await audioHandler.playMediaItem(MediaItem(
      id: widget.audioAssetPath,
      album: "Audiobook Library",
      title: widget.title,
      artist: "Various Artists",
    ));
  }

  @override
  void dispose() {
    _noScreenshot.screenshotOn();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Audiobook Player")),
      body: StreamBuilder<PlaybackState>(
        stream: audioHandler.playbackState,
        builder: (context, snapshot) {
          final playbackState = snapshot.data;
          final processingState = playbackState?.processingState ?? AudioProcessingState.idle;
          final playing = playbackState?.playing ?? false;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.headset, size: 100, color: Colors.blueGrey),
                const SizedBox(height: 32),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                _buildSeekBar(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_10, size: 48),
                      onPressed: () => audioHandler.seek(
                        (playbackState?.position ?? Duration.zero) - const Duration(seconds: 10),
                      ),
                    ),
                    const SizedBox(width: 16),
                    CircleAvatar(
                      radius: 40,
                      child: IconButton(
                        icon: Icon(
                          playing ? Icons.pause : Icons.play_arrow,
                          size: 48,
                        ),
                        onPressed: playing ? audioHandler.pause : audioHandler.play,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.forward_10, size: 48),
                      onPressed: () => audioHandler.seek(
                        (playbackState?.position ?? Duration.zero) + const Duration(seconds: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (processingState == AudioProcessingState.loading ||
                    processingState == AudioProcessingState.buffering)
                  const CircularProgressIndicator(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSeekBar() {
    return StreamBuilder<Duration>(
      stream: AudioService.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final mediaItem = audioHandler.mediaItem.value;
        final duration = mediaItem?.duration ?? Duration.zero;

        return Column(
          children: [
            Slider(
              min: 0,
              max: duration.inMilliseconds.toDouble() > 0 
                  ? duration.inMilliseconds.toDouble() 
                  : position.inMilliseconds.toDouble() + 1000,
              value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble() > 0 
                  ? duration.inMilliseconds.toDouble() 
                  : position.inMilliseconds.toDouble() + 1000),
              onChanged: (value) {
                audioHandler.seek(Duration(milliseconds: value.toInt()));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position)),
                  Text(_formatDuration(duration)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
