import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => 'AuthException: $message';
}

class AuthService {
  final String apiUrl;
  final http.Client _client;

  AuthService({required this.apiUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<String> login(String email, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$apiUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['access_token'];
        if (token == null || token is! String) {
          throw AuthException('서버 응답 오류: access_token 없음');
        }
        return token;
      }
      if (response.statusCode == 401) {
        throw AuthException('이메일 또는 비밀번호가 올바르지 않습니다.');
      }
      if (response.statusCode >= 500) {
        throw AuthException('서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
      }
      throw AuthException('로그인 실패: HTTP ${response.statusCode}');
    } on AuthException {
      rethrow;
    } on SocketException {
      throw AuthException('서버에 연결할 수 없습니다. 인터넷 연결을 확인해주세요.');
    } on TimeoutException {
      throw AuthException('연결 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.');
    } catch (e) {
      throw AuthException('예기치 않은 오류가 발생했습니다.');
    }
  }
}
