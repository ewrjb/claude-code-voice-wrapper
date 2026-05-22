import 'package:flutter/material.dart';
import '../models/app_state.dart';

class StatusOrb extends StatelessWidget {
  final VoiceState state;

  const StatusOrb({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _bgColor,
            border: Border.all(color: _borderColor, width: 2),
            boxShadow: [BoxShadow(color: _borderColor.withOpacity(0.4), blurRadius: 16)],
          ),
          child: Center(child: Text(_icon, style: const TextStyle(fontSize: 32))),
        ),
        const SizedBox(height: 8),
        Text(_label, style: TextStyle(color: _borderColor, fontSize: 14)),
      ],
    );
  }

  Color get _bgColor => switch (state) {
        VoiceState.idle => const Color(0xFF21262D),
        VoiceState.recording => const Color(0xFF0D2818),
        VoiceState.processing => const Color(0xFF1A1040),
        VoiceState.speaking => const Color(0xFF1A2840),
        VoiceState.agentOffline => const Color(0xFF21262D),
      };

  Color get _borderColor => switch (state) {
        VoiceState.idle => const Color(0xFF30363D),
        VoiceState.recording => const Color(0xFF3FB950),
        VoiceState.processing => const Color(0xFFD2A8FF),
        VoiceState.speaking => const Color(0xFF58A6FF),
        VoiceState.agentOffline => const Color(0xFFE74C3C),
      };

  String get _icon => switch (state) {
        VoiceState.idle => '🤖',
        VoiceState.recording => '🎤',
        VoiceState.processing => '⚙️',
        VoiceState.speaking => '🔊',
        VoiceState.agentOffline => '🖥️',
      };

  String get _label => switch (state) {
        VoiceState.idle => '준비됨',
        VoiceState.recording => '듣는 중...',
        VoiceState.processing => '작업 중...',
        VoiceState.speaking => '말하는 중...',
        VoiceState.agentOffline => '에이전트 오프라인',
      };
}
