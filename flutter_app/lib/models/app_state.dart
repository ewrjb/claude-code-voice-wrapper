import 'package:flutter/foundation.dart';

enum VoiceState {
  idle,
  recording,
  processing,
  speaking,
  agentOffline,
}

class AppStateNotifier extends ChangeNotifier {
  VoiceState _voiceState = VoiceState.agentOffline;
  String _lastMessage = '';

  VoiceState get voiceState => _voiceState;
  String get lastMessage => _lastMessage;

  bool get canRecord => _voiceState == VoiceState.idle;

  void setVoiceState(VoiceState state) {
    if (_voiceState != state) {
      _voiceState = state;
      notifyListeners();
    }
  }

  void setAgentOnline(bool online) {
    setVoiceState(online ? VoiceState.idle : VoiceState.agentOffline);
  }

  void setLastMessage(String message) {
    if (_lastMessage != message) {
      _lastMessage = message;
      notifyListeners();
    }
  }

  int _commandCount = 0;
  int get commandCount => _commandCount;

  void incrementCommandCount() {
    _commandCount++;
    notifyListeners();
  }

  void resetCommandCount() {
    _commandCount = 0;
    notifyListeners();
  }
}
