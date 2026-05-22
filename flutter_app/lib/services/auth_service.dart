import 'dart:convert';
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
        return data['access_token'] as String;
      }
      throw AuthException('로그인 실패: HTTP ${response.statusCode}');
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('네트워크 오류: $e');
    }
  }
}
