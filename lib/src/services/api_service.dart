import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../config/env.dart';

class ApiService {
  final String baseUrl = Env.apiBaseUrl;

  // API service implementation
  Future<Map<String, dynamic>> get(String endpoint) async {
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
        'API GET Error',
        name: 'ApiService',
        error: {
          'URL': url,
          'Method': 'GET',
          'Request Body': null,
          'Error': e.toString(),
        },
      );
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
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
      developer.log(
        'API POST Error',
        name: 'ApiService',
        error: {
          'URL': url,
          'Method': 'POST',
          'Request Body': data,
          'Error': e.toString(),
        },
      );
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
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
      developer.log(
        'API PUT Error',
        name: 'ApiService',
        error: {
          'URL': url,
          'Method': 'PUT',
          'Request Body': data,
          'Error': e.toString(),
        },
      );
      throw Exception('Network error: $e');
    }
  }

  Future<void> delete(String endpoint) async {
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
        'API DELETE Error',
        name: 'ApiService',
        error: {
          'URL': url,
          'Method': 'DELETE',
          'Request Body': null,
          'Error': e.toString(),
        },
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
      Map<String, dynamic>? responseBody;
      try {
        responseBody = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        // If response is not JSON, log as string
        responseBody = {'raw': response.body};
      }

      developer.log(
        'API Call: $method $url',
        name: 'ApiService',
        error: {
          'URL': url,
          'Method': method,
          'Status Code': response.statusCode,
          'Request Body': requestBody,
          'Response Body': responseBody,
        },
      );
    } catch (e) {
      developer.log(
        'API Call Logging Error',
        name: 'ApiService',
        error: {
          'URL': url,
          'Method': method,
          'Status Code': response.statusCode,
          'Request Body': requestBody,
          'Response Body (Raw)': response.body,
          'Logging Error': e.toString(),
        },
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
