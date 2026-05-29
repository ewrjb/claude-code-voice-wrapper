import 'dart:async';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _speaking = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  /// iOS: AVAudioSession을 .playback 카테고리로 재설정한다.
  /// SpeechToText가 .record 카테고리로 바꿔놓으면 TTS가 무음이 되므로,
  /// 매 발화 전에 명시적으로 복원해야 한다.
  Future<void> _configureIosAudioSession() async {
    if (!Platform.isIOS) return;
    await _tts.setSharedInstance(true);
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ],
      IosTextToSpeechAudioMode.defaultMode,
    );
  }

  /// Speaks [text] and completes when done.
  Future<void> speak(String text) async {
    await initialize();
    // STT 사용 후 iOS 오디오 세션이 .record 상태로 남을 수 있으므로
    // 발화 직전에 .playback으로 재설정한다.
    await _configureIosAudioSession();
    if (_speaking) {
      await _tts.stop();
    }
    _speaking = true;
    final completer = Completer<void>();
    _tts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    _tts.setCancelHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    _tts.setErrorHandler((_) {
      if (!completer.isCompleted) completer.complete();
    });
    await _tts.speak(text);
    await completer.future;
    _speaking = false;
  }

  Future<void> stop() async {
    _speaking = false;
    await _tts.stop();
  }
}
