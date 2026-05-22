import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/app_state.dart';
import '../services/relay_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../widgets/mic_button.dart';
import '../widgets/status_orb.dart';

class MainScreen extends StatefulWidget {
  @visibleForTesting
  final RelayService? relayOverride;

  const MainScreen({super.key, this.relayOverride});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  RelayService? _relay;
  final SttService _stt = SttService();
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initRelay());
  }

  Future<void> _initRelay() async {
    final appState = context.read<AppStateNotifier>();
    if (widget.relayOverride != null) {
      _relay = widget.relayOverride!;
    } else {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      _relay = RelayService(wsUrl: AppConfig.wsUrl, token: token);
    }
    _relay!.onAgentStatus = (online) {
      if (mounted) appState.setAgentOnline(online);
    };
    _relay!.onResponse = (text) async {
      if (!mounted) return;
      appState.setLastMessage(text);
      appState.setVoiceState(VoiceState.speaking);
      await _tts.speak(text);
      if (mounted) appState.setVoiceState(VoiceState.idle);
    };
    _relay!.onError = (text) {
      if (!mounted) return;
      appState.setLastMessage('오류: $text');
      appState.setVoiceState(VoiceState.idle);
    };
    _relay!.onDisconnected = () {
      if (mounted) appState.setAgentOnline(false);
    };
    await _relay!.connect();
  }

  Future<void> _onMicPressStart() async {
    final appState = context.read<AppStateNotifier>();
    if (!appState.canRecord) return;
    appState.setVoiceState(VoiceState.recording);
    await _stt.startListening(
      onResult: (text) {
        if (mounted) appState.setLastMessage(text);
      },
    );
  }

  Future<void> _onMicPressEnd() async {
    final appState = context.read<AppStateNotifier>();
    if (appState.voiceState != VoiceState.recording) return;
    await _stt.stopListening();
    if (!mounted) return;
    final text = appState.lastMessage.trim();
    if (text.isEmpty) {
      appState.setVoiceState(VoiceState.idle);
      return;
    }
    appState.setVoiceState(VoiceState.processing);
    _relay?.sendCommand(text);
  }

  @override
  void dispose() {
    _relay?.disconnect();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateNotifier>(
      builder: (context, appState, _) {
        final voiceState = appState.voiceState;
        return Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          body: SafeArea(
            child: Column(
              children: [
                _buildStatusBar(voiceState),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StatusOrb(state: voiceState),
                      const SizedBox(height: 24),
                      _buildLastMessage(appState.lastMessage),
                      const SizedBox(height: 32),
                      MicButton(
                        state: voiceState,
                        onPressStart: _onMicPressStart,
                        onPressEnd: _onMicPressEnd,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBar(VoiceState state) {
    final online = state != VoiceState.agentOffline;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online
                  ? const Color(0xFF3FB950)
                  : const Color(0xFFE74C3C),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            online ? '연결됨' : '연결 안됨',
            style: TextStyle(
              fontSize: 12,
              color: online
                  ? const Color(0xFF3FB950)
                  : const Color(0xFFE74C3C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastMessage(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message.isEmpty ? '이전 대화 없음' : message,
        style: TextStyle(
          fontSize: 13,
          color: message.isEmpty
              ? const Color(0xFF444444)
              : const Color(0xFF8B949E),
        ),
      ),
    );
  }
}
