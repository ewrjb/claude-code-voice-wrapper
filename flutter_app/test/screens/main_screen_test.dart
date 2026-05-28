import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:voice_dev/models/app_state.dart';
import 'package:voice_dev/screens/main_screen.dart';
import 'package:voice_dev/services/relay_service.dart';

class FakeRelayService extends RelayService {
  FakeRelayService()
      : super(wsUrl: 'ws://fake.localhost', token: 'fake-token');

  @override Future<void> connect() async {}
  @override void sendCommand(String text) {}
  @override void sendNewSession() {}
  @override Future<void> disconnect() async {}
}

Widget makeApp(AppStateNotifier state) => ChangeNotifierProvider<AppStateNotifier>.value(
      value: state,
      child: MaterialApp(
        home: MainScreen(relayOverride: FakeRelayService()),
      ),
    );

void main() {
  testWidgets('shows agent offline state by default', (tester) async {
    final state = AppStateNotifier();
    await tester.pumpWidget(makeApp(state));
    expect(find.text('에이전트 오프라인'), findsOneWidget);
  });

  testWidgets('shows idle state when agent comes online', (tester) async {
    final state = AppStateNotifier();
    await tester.pumpWidget(makeApp(state));
    state.setAgentOnline(true);
    await tester.pump();
    expect(find.text('준비됨'), findsOneWidget);
  });

  testWidgets('shows mic_button_disabled when agent offline', (tester) async {
    final state = AppStateNotifier();
    await tester.pumpWidget(makeApp(state));
    expect(find.byKey(const Key('mic_button_disabled')), findsOneWidget);
  });

  testWidgets('shows mic_button_enabled when agent online', (tester) async {
    final state = AppStateNotifier();
    state.setAgentOnline(true);
    await tester.pumpWidget(makeApp(state));
    expect(find.byKey(const Key('mic_button_enabled')), findsOneWidget);
  });

  testWidgets('displays last message text', (tester) async {
    final state = AppStateNotifier();
    state.setAgentOnline(true);
    state.setLastMessage('토큰 만료 수정했어요.');
    await tester.pumpWidget(makeApp(state));
    expect(find.text('토큰 만료 수정했어요.'), findsOneWidget);
  });

  testWidgets('hint text shows 탭해서 말하기 when idle', (tester) async {
    final state = AppStateNotifier();
    state.setAgentOnline(true);
    await tester.pumpWidget(makeApp(state));
    expect(find.text('탭해서 말하기'), findsOneWidget);
  });

  testWidgets('shows new_session_button when agent online', (tester) async {
    final state = AppStateNotifier();
    state.setAgentOnline(true);
    await tester.pumpWidget(makeApp(state));
    expect(find.byKey(const Key('new_session_button')), findsOneWidget);
  });

  testWidgets('shows session counter after commandCount increments', (tester) async {
    final state = AppStateNotifier();
    state.setAgentOnline(true);
    state.incrementCommandCount();
    await tester.pumpWidget(makeApp(state));
    await tester.pump();
    expect(find.text('세션 1번째'), findsOneWidget);
  });
}
