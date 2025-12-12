import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../config/env.dart';
import 'connectivity_service.dart';

class ApiService {
  final String baseUrl = Env.apiBaseUrl;
  final ConnectivityService _connectivityService = ConnectivityService();

  // API service implementation
  Future<Map<String, dynamic>> get(String endpoint) async {
    // Check internet connection before making API call
    final hasInternet = await _connectivityService.hasInternetConnection();
    if (!hasInternet) {
      throw Exception(
        'No internet connection. Please check your network settings.',
      );
    }
    final url = '$baseUrl$endpoint';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      _logApiCall('GET', url, null, response);
      return _handleResponse(response);
    } catch (e) {
      developer.log(
        'API GET Error\nURL: $url\nMethod: GET\nError: ${e.toString()}',
        name: 'ApiService',
        error: e,
      );
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    // Check internet connection before making API call
    final hasInternet = await _connectivityService.hasInternetConnection();
    if (!hasInternet) {
      throw Exception(
        'No internet connection. Please check your network settings.',
      );
    }

    final url = '$baseUrl$endpoint';
    final requestBody = jsonEncode(data);
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      _logApiCall('POST', url, data, response);
      return _handleResponse(response);
    } catch (e) {
      final requestBodyStr = const JsonEncoder.withIndent('  ').convert(data);
      developer.log(
        'API POST Error\nURL: $url\nMethod: POST\nRequest Body:\n$requestBodyStr\nError: ${e.toString()}',
        name: 'ApiService',
        error: e,
      );
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    // Check internet connection before making API call
    final hasInternet = await _connectivityService.hasInternetConnection();
    if (!hasInternet) {
      throw Exception(
        'No internet connection. Please check your network settings.',
      );
    }

    final url = '$baseUrl$endpoint';
    final requestBody = jsonEncode(data);
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      _logApiCall('PUT', url, data, response);
      return _handleResponse(response);
    } catch (e) {
      final requestBodyStr = const JsonEncoder.withIndent('  ').convert(data);
      developer.log(
        'API PUT Error\nURL: $url\nMethod: PUT\nRequest Body:\n$requestBodyStr\nError: ${e.toString()}',
        name: 'ApiService',
        error: e,
      );
      throw Exception('Network error: $e');
    }
  }

  Future<void> delete(String endpoint) async {
    // Check internet connection before making API call
    final hasInternet = await _connectivityService.hasInternetConnection();
    if (!hasInternet) {
      throw Exception(
        'No internet connection. Please check your network settings.',
      );
    }

    final url = '$baseUrl$endpoint';
    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      _logApiCall('DELETE', url, null, response);
      _handleResponse(response);
    } catch (e) {
      developer.log(
        'API DELETE Error\nURL: $url\nMethod: DELETE\nError: ${e.toString()}',
        name: 'ApiService',
        error: e,
      );
      throw Exception('Network error: $e');
    }
  }

  /// Log complete API call information (URL, Request Body, Response Body) in one entry
  void _logApiCall(
    String method,
    String url,
    Map<String, dynamic>? requestBody,
    http.Response response,
  ) {
    try {
      // Convert request body to JSON string for full visibility
      String requestBodyStr = 'null';
      if (requestBody != null) {
        try {
          const encoder = JsonEncoder.withIndent('  ');
          requestBodyStr = encoder.convert(requestBody);
        } catch (e) {
          requestBodyStr = requestBody.toString();
        }
      }

      // Convert response body to JSON string for full visibility
      String responseBodyStr = '';
      try {
        final responseBody = jsonDecode(response.body);
        const encoder = JsonEncoder.withIndent('  ');
        responseBodyStr = encoder.convert(responseBody);
      } catch (e) {
        // If response is not JSON, log as string
        responseBodyStr = response.body;
      }

      // Log everything in a single, readable format
      final logMessage =
          '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
API Call: $method $url
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Status Code: ${response.statusCode}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Request Body:
$requestBodyStr
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Response Body:
$responseBodyStr
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';

      developer.log(logMessage, name: 'ApiService');
    } catch (e) {
      developer.log(
        'API Call Logging Error: $e\nURL: $url\nMethod: $method\nStatus Code: ${response.statusCode}\nRequest Body: ${requestBody?.toString() ?? 'null'}\nResponse Body (Raw): ${response.body}',
        name: 'ApiService',
        error: e,
      );
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('API error: ${response.statusCode} - ${response.body}');
    }
  }
}
