import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:voice_dev/services/auth_service.dart';
import 'auth_service_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  late MockClient mockClient;
  late AuthService service;

  setUp(() {
    mockClient = MockClient();
    service = AuthService(
      apiUrl: 'http://test.relay:8000',
      client: mockClient,
    );
  });

  test('login returns token on 200', () async {
    when(mockClient.post(
      Uri.parse('http://test.relay:8000/auth/login'),
      headers: anyNamed('headers'),
      body: anyNamed('body'),
    )).thenAnswer((_) async =>
        http.Response('{"access_token":"eyJ.test.token"}', 200));

    final token = await service.login('user@example.com', 'password123');
    expect(token, equals('eyJ.test.token'));
  });

  test('login throws AuthException on 401', () async {
    when(mockClient.post(any,
            headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer(
            (_) async => http.Response('{"detail":"Invalid credentials"}', 401));

    await expectLater(
      service.login('user@example.com', 'wrong'),
      throwsA(isA<AuthException>()),
    );
  });

  test('login throws AuthException on network error', () async {
    when(mockClient.post(any,
            headers: anyNamed('headers'), body: anyNamed('body')))
        .thenThrow(Exception('Network error'));

    await expectLater(
      service.login('user@example.com', 'password'),
      throwsA(isA<AuthException>()),
    );
  });

  test('SocketException shows friendly connection message', () async {
    when(mockClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenThrow(const SocketException('Connection refused'));
    await expectLater(
      service.login('a@b.com', 'pass'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          '서버에 연결할 수 없습니다. 인터넷 연결을 확인해주세요.',
        ),
      ),
    );
  });

  test('TimeoutException shows friendly timeout message', () async {
    when(mockClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenThrow(TimeoutException('timed out'));
    await expectLater(
      service.login('a@b.com', 'pass'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          '연결 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.',
        ),
      ),
    );
  });

  test('HTTP 401 shows friendly auth error', () async {
    when(mockClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer((_) async => http.Response('{"detail":"unauthorized"}', 401));
    await expectLater(
      service.login('a@b.com', 'wrong'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          '이메일 또는 비밀번호가 올바르지 않습니다.',
        ),
      ),
    );
  });

  test('HTTP 500 shows friendly server error', () async {
    when(mockClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer((_) async => http.Response('Internal Server Error', 500));
    await expectLater(
      service.login('a@b.com', 'pass'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
        ),
      ),
    );
  });
}
