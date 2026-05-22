import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;

  Future<bool> initialize() async {
    _initialized = await _stt.initialize(
      onError: (error) => _initialized = false,
    );
    return _initialized;
  }

  /// Starts listening. Calls [onResult] with intermediate + final results.
  Future<void> startListening({required void Function(String) onResult}) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;
    await _stt.listen(
      onResult: (result) => onResult(result.recognizedWords),
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'ko_KR',
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
  }

  bool get isListening => _stt.isListening;
}
