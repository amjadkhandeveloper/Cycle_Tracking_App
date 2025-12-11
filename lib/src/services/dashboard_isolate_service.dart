import 'dart:isolate';
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../config/env.dart';

/// Isolate entry point for dashboard API calls
/// This runs in a separate isolate to avoid blocking the UI
@pragma('vm:entry-point') // Required for Flutter release builds
void dashboardIsolateEntry(SendPort sendPort) async {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  await for (final message in receivePort) {
    if (message is Map<String, dynamic>) {
      final userId = message['userId'] as String;
      final vehicleNo = message['vehicleNo'] as String;
      final resultPort = message['resultPort'] as SendPort;

      try {
        final url = '${Env.apiBaseUrl}${Env.apiDashboard}';
        final requestBody = {'user_id': userId, 'vehicle_no': vehicleNo};

        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        // Log complete API call (URL, Request Body, Response Body) in one entry
        try {
          // Convert request body to JSON string for full visibility
          String requestBodyStr;
          try {
            const encoder = JsonEncoder.withIndent('  ');
            requestBodyStr = encoder.convert(requestBody);
          } catch (e) {
            requestBodyStr = requestBody.toString();
          }

          // Convert response body to JSON string for full visibility
          String responseBodyStr = '';
          try {
            final responseBody = jsonDecode(response.body);
            const encoder = JsonEncoder.withIndent('  ');
            responseBodyStr = encoder.convert(responseBody);
          } catch (e) {
            responseBodyStr = response.body;
          }

          final logMessage =
              '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
API Call (Isolate): POST $url
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

          developer.log(logMessage, name: 'DashboardIsolateService');
        } catch (logError) {
          developer.log(
            'API Call Logging Error\nURL: $url\nMethod: POST\nStatus Code: ${response.statusCode}\nResponse Body (Raw): ${response.body}\nLogging Error: ${logError.toString()}',
            name: 'DashboardIsolateService',
            error: logError,
          );
        }

        if (response.statusCode == 200) {
          final responseData =
              jsonDecode(response.body) as Map<String, dynamic>;
          resultPort.send({'success': true, 'data': responseData});
        } else {
          resultPort.send({
            'success': false,
            'error': 'API returned status code ${response.statusCode}',
            'responseBody': response.body,
          });
        }
      } catch (e) {
        final requestBodyStr = const JsonEncoder.withIndent(
          '  ',
        ).convert({'user_id': userId, 'vehicle_no': vehicleNo});
        developer.log(
          'API POST Error (Isolate)\nURL: ${Env.apiBaseUrl}${Env.apiDashboard}\nRequest Body:\n$requestBodyStr\nError: ${e.toString()}',
          name: 'DashboardIsolateService',
          error: e,
        );
        resultPort.send({'success': false, 'error': e.toString()});
      }
    }
  }
}

/// Service for managing dashboard API calls in an isolate
class DashboardIsolateService {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;

  /// Initialize the isolate
  Future<void> initialize() async {
    if (_isolate != null) {
      return; // Already initialized
    }

    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      dashboardIsolateEntry,
      _receivePort!.sendPort,
    );

    // Wait for the isolate to send its SendPort
    _sendPort = await _receivePort!.first as SendPort;
  }

  /// Call the dashboard API
  Future<Map<String, dynamic>> fetchDashboardData({
    required String userId,
    required String vehicleNo,
  }) async {
    if (_sendPort == null) {
      await initialize();
    }

    final completer = Completer<Map<String, dynamic>>();
    final resultPort = ReceivePort();

    resultPort.listen((result) {
      completer.complete(result as Map<String, dynamic>);
      resultPort.close();
    });

    _sendPort!.send({
      'userId': userId,
      'vehicleNo': vehicleNo,
      'resultPort': resultPort.sendPort,
    });

    return completer.future;
  }

  /// Dispose the isolate
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _receivePort?.close();
    _receivePort = null;
  }
}
