import 'api_service.dart';
import '../config/env.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _apiService.post(Env.apiAuthLogin, {
        'username': username,
        'password': password,
      });

      return response;
    } catch (e) {
      return {'status': 0, 'message': 'Login failed: $e', 'data': null};
    }
  }

  Future<bool> register(
    String email,
    String password,
    Map<String, dynamic> userData,
  ) async {
    // Implementation here
    throw UnimplementedError();
  }

  Future<void> logout() async {
    // Implementation here
    throw UnimplementedError();
  }

  Future<bool> isAuthenticated() async {
    // Implementation here
    throw UnimplementedError();
  }
}
