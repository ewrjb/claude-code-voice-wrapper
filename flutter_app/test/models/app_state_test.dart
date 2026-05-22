import 'package:flutter_test/flutter_test.dart';
import 'package:voice_dev/models/app_state.dart';

void main() {
  late AppStateNotifier notifier;

  setUp(() => notifier = AppStateNotifier());

  test('initial state is agentOffline', () {
    expect(notifier.voiceState, equals(VoiceState.agentOffline));
  });

  test('setAgentOnline(true) transitions to idle', () {
    notifier.setAgentOnline(true);
    expect(notifier.voiceState, equals(VoiceState.idle));
  });

  test('setAgentOnline(false) transitions to agentOffline', () {
    notifier.setAgentOnline(true);
    notifier.setAgentOnline(false);
    expect(notifier.voiceState, equals(VoiceState.agentOffline));
  });

  test('setVoiceState updates state and notifies', () {
    bool notified = false;
    notifier.addListener(() => notified = true);
    notifier.setVoiceState(VoiceState.recording);
    expect(notifier.voiceState, equals(VoiceState.recording));
    expect(notified, isTrue);
  });

  test('canRecord is true only in idle state', () {
    notifier.setAgentOnline(true);
    expect(notifier.canRecord, isTrue);
    notifier.setVoiceState(VoiceState.processing);
    expect(notifier.canRecord, isFalse);
  });

  test('setLastMessage updates message and notifies', () {
    bool notified = false;
    notifier.addListener(() => notified = true);
    notifier.setLastMessage('테스트 완료');
    expect(notifier.lastMessage, equals('테스트 완료'));
    expect(notified, isTrue);
  });

  test('setVoiceState same value does not notify', () {
    int count = 0;
    notifier.addListener(() => count++);
    notifier.setVoiceState(VoiceState.agentOffline); // same as initial
    expect(count, equals(0));
  });
}
