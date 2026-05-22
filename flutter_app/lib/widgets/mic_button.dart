import 'package:flutter/material.dart';
import '../models/app_state.dart';

class MicButton extends StatelessWidget {
  final VoiceState state;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;

  const MicButton({
    super.key,
    required this.state,
    this.onPressStart,
    this.onPressEnd,
  });

  bool get _enabled => state == VoiceState.idle || state == VoiceState.recording;
  bool get _active => state == VoiceState.recording;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          key: _enabled
              ? const Key('mic_button_enabled')
              : const Key('mic_button_disabled'),
          onPanStart: _enabled ? (_) => onPressStart?.call() : null,
          onPanEnd: _enabled ? (_) => onPressEnd?.call() : null,
          onTapDown: _enabled ? (_) => onPressStart?.call() : null,
          onTapUp: _enabled ? (_) => onPressEnd?.call() : null,
          onTapCancel: _enabled ? onPressEnd : null,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _active
                  ? const Color(0xFF0D2818)
                  : _enabled
                      ? const Color(0xFF21262D)
                      : const Color(0xFF161B22),
              border: Border.all(
                color: _active
                    ? const Color(0xFF3FB950)
                    : _enabled
                        ? const Color(0xFF444444)
                        : const Color(0xFF30363D),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                '🎤',
                style: TextStyle(
                  fontSize: 24,
                  color: _enabled ? null : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _hint,
          style: TextStyle(
            fontSize: 11,
            color: _active
                ? const Color(0xFF3FB950)
                : const Color(0xFF6E7681),
          ),
        ),
      ],
    );
  }

  String get _hint => switch (state) {
        VoiceState.idle => '버튼을 누르고 말하세요',
        VoiceState.recording => '손 떼면 전송',
        VoiceState.processing => '작업 중 — 잠시만요',
        VoiceState.speaking => '재생 중...',
        VoiceState.agentOffline => '에이전트 연결 필요',
      };
}
