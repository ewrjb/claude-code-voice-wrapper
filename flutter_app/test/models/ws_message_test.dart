import 'package:flutter_test/flutter_test.dart';
import 'package:voice_dev/models/ws_message.dart';

void main() {
  group('WsMessage.fromJson', () {
    test('parses agent_status online', () {
      final msg = WsMessage.fromJson('{"type":"agent_status","online":true}');
      expect(msg.type, equals('agent_status'));
      expect(msg.isAgentStatus, isTrue);
      expect(msg.agentOnline, isTrue);
    });

    test('parses agent_status offline', () {
      final msg = WsMessage.fromJson('{"type":"agent_status","online":false}');
      expect(msg.agentOnline, isFalse);
    });

    test('parses response message', () {
      final msg = WsMessage.fromJson('{"type":"response","text":"완료했습니다."}');
      expect(msg.isResponse, isTrue);
      expect(msg.text, equals('완료했습니다.'));
    });

    test('parses error message', () {
      final msg = WsMessage.fromJson('{"type":"error","text":"오류 발생"}');
      expect(msg.isError, isTrue);
      expect(msg.text, equals('오류 발생'));
    });

    test('throws on invalid json', () {
      expect(
        () => WsMessage.fromJson('not-json'),
        throwsA(anything),
      );
    });
  });

  group('WsMessage.command', () {
    test('produces correct JSON', () {
      final json = WsMessage.command('로그인 버그 고쳐줘');
      expect(json, contains('"type":"command"'));
      expect(json, contains('"text":"로그인 버그 고쳐줘"'));
    });
  });
}
