import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Global instance of the audio handler
late MyAudioHandler audioHandler;

/// An [AudioHandler] that uses [just_audio] to play audio.
/// This enables background playback and lock screen controls.
class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();

  MyAudioHandler() {
    // Sync player state to audio_service's playbackState
    _player.playbackEventStream.listen(_onPlaybackEvent);
    _player.playerStateStream.listen((state) => _broadcastState());
    _player.positionStream.listen((pos) => _broadcastState());
    _player.bufferedPositionStream.listen((buf) => _broadcastState());
    
    // Initial state broadcast
    _broadcastState();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  /// Loads an audio file (from asset or local path) and plays it.
  @override
  Future<void> playMediaItem(MediaItem item) async {
    try {
      final String source = item.id;
      debugPrint("Loading audio source: $source");
      
      final Duration? duration;
      if (source.startsWith('assets/')) {
        duration = await _player.setAsset(source);
      } else {
        // Assume it's a local file path
        duration = await _player.setAudioSource(AudioSource.file(source));
      }
      
      // Update the current media item with its duration
      mediaItem.add(item.copyWith(duration: duration));
      
      debugPrint("Audio loaded successfully. Duration: $duration");
      await play();
    } catch (e) {
      debugPrint("Error loading or playing audio: $e");
      // Optionally broadcast an error state
      _broadcastState();
    }
  }

  void _onPlaybackEvent(PlaybackEvent event) {
    _broadcastState();
  }

  /// Broadcasts the current player state to the audio_service [playbackState] stream.
  void _broadcastState() {
    final playing = _player.playing;
    final processingState = _player.processingState;
    
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.rewind,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[processingState] ?? AudioProcessingState.idle,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: 0, 
    ));
  }
}
