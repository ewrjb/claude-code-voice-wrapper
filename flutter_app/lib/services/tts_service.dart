import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  /// Speaks [text] and completes when done.
  Future<void> speak(String text) async {
    await initialize();
    final completer = Completer<void>();
    _tts.setCompletionHandler(() => completer.complete());
    _tts.setCancelHandler(() => completer.complete());
    await _tts.speak(text);
    await completer.future;
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
