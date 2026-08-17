import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool isSpeaking = false;
  bool isPaused = false;

  Function(bool speaking)? onSpeechStateChanged;

  /// Initialize TTS settings.
  Future<void> init() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.awaitSpeakCompletion(false);

      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
      );

      _flutterTts.setStartHandler(() {
        isSpeaking = true;
        isPaused = false;
        onSpeechStateChanged?.call(true);
      });

      _flutterTts.setCompletionHandler(() {
        isSpeaking = false;
        isPaused = false;
        onSpeechStateChanged?.call(false);
      });

      _flutterTts.setCancelHandler(() {
        isSpeaking = false;
        isPaused = false;
        onSpeechStateChanged?.call(false);
      });

      _flutterTts.setPauseHandler(() {
        isSpeaking = false;
        isPaused = true;
        onSpeechStateChanged?.call(false);
      });

      _flutterTts.setContinueHandler(() {
        isSpeaking = true;
        isPaused = false;
        onSpeechStateChanged?.call(true);
      });

      _flutterTts.setErrorHandler((msg) {
        isSpeaking = false;
        isPaused = false;
        onSpeechStateChanged?.call(false);
        debugPrint("TTS error: $msg");
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint("Error initializing TTS: $e");
    }
  }

  /// Speaks the provided text instantly (word, sentence, or paragraph).
  Future<void> speak(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    if (!_isInitialized) {
      await init();
    }

    try {
      await _flutterTts.stop();
      await _flutterTts.speak(cleanText);
    } catch (e) {
      debugPrint("TTS speak error: $e");
    }
  }

  Future<void> pause() async {
    await _flutterTts.pause();
  }

  Future<void> stop() async {
    isSpeaking = false;
    isPaused = false;
    onSpeechStateChanged?.call(false);
    await _flutterTts.stop();
  }
}
