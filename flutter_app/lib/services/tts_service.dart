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
    await _selectBestKoreanVoice();
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  /// 사용 가능한 한국어 음성 중 가장 품질이 높은 것을 선택한다.
  /// iOS: Premium > Enhanced > Standard 순으로 선호.
  /// 실패 시 시스템 기본 음성으로 fallback.
  Future<void> _selectBestKoreanVoice() async {
    try {
      final raw = await _tts.getVoices;
      if (raw == null) return;
      final voices = (raw as List)
          .cast<Map<dynamic, dynamic>>()
          .where((v) {
            final locale = (v['locale'] as String? ?? '').toLowerCase();
            return locale.startsWith('ko');
          })
          .toList();
      if (voices.isEmpty) return;

      // Siri 음성 2 → Premium → Enhanced → (첫 번째 한국어 음성) 순으로 선택
      Map<dynamic, dynamic>? selected;
      for (final keyword in ['Siri 음성 2', 'Siri Voice 2', 'Premium', 'Enhanced']) {
        try {
          selected = voices.firstWhere(
            (v) => (v['name'] as String? ?? '').contains(keyword),
          );
          break;
        } catch (_) {
          // 해당 음성 없음, 다음 후보 시도
        }
      }
      selected ??= voices.first;

      await _tts.setVoice({
        'name': selected['name'] as String,
        'locale': selected['locale'] as String,
      });
    } catch (_) {
      // 음성 선택 실패 시 시스템 기본 음성 사용
    }
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
