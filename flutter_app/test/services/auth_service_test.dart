import 'dart:convert';
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

    expect(
      service.login('user@example.com', 'wrong'),
      throwsA(isA<AuthException>()),
    );
  });

  test('login throws AuthException on network error', () async {
    when(mockClient.post(any,
            headers: anyNamed('headers'), body: anyNamed('body')))
        .thenThrow(Exception('Network error'));

    expect(
      service.login('user@example.com', 'password'),
      throwsA(isA<AuthException>()),
    );
  });
}
