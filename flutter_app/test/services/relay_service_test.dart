import 'package:flutter_test/flutter_test.dart';
import 'package:voice_dev/services/relay_service.dart';

void main() {
  group('RelayService.processIncoming', () {
    test('agent_status online → onAgentStatus(true)', () {
      bool? result;
      RelayService.processIncoming(
        '{"type":"agent_status","online":true}',
        onAgentStatus: (v) => result = v,
        onResponse: (_) {},
        onError: (_) {},
      );
      expect(result, isTrue);
    });

    test('agent_status offline → onAgentStatus(false)', () {
      bool? result;
      RelayService.processIncoming(
        '{"type":"agent_status","online":false}',
        onAgentStatus: (v) => result = v,
        onResponse: (_) {},
        onError: (_) {},
      );
      expect(result, isFalse);
    });

    test('response message → onResponse with text', () {
      String? result;
      RelayService.processIncoming(
        '{"type":"response","text":"테스트 완료했습니다."}',
        onAgentStatus: (_) {},
        onResponse: (v) => result = v,
        onError: (_) {},
      );
      expect(result, equals('테스트 완료했습니다.'));
    });

    test('error message → onError with text', () {
      String? result;
      RelayService.processIncoming(
        '{"type":"error","text":"오류 발생"}',
        onAgentStatus: (_) {},
        onResponse: (_) {},
        onError: (v) => result = v,
      );
      expect(result, equals('오류 발생'));
    });

    test('invalid json is ignored silently', () {
      expect(
        () => RelayService.processIncoming(
          'not-json',
          onAgentStatus: (_) {},
          onResponse: (_) {},
          onError: (_) {},
        ),
        returnsNormally,
      );
    });

    test('unknown type calls no callback', () {
      bool called = false;
      RelayService.processIncoming(
        '{"type":"ping"}',
        onAgentStatus: (_) => called = true,
        onResponse: (_) => called = true,
        onError: (_) => called = true,
      );
      expect(called, isFalse);
    });
  });
}
