import 'dart:isolate';
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../config/env.dart';

/// Isolate entry point for background sync
/// This runs in a separate isolate to avoid blocking the UI
@pragma('vm:entry-point') // Required for Flutter release builds
void syncIsolateEntry(SendPort sendPort) async {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  await for (final message in receivePort) {
    if (message is Map<String, dynamic>) {
      final locations = message['locations'] as List<Map<String, dynamic>>;
      final resultPort = message['resultPort'] as SendPort;

      try {
        int syncedCount = 0;
        int failedCount = 0;
        List<int> syncedIds = [];
        final url = '${Env.apiBaseUrl}${Env.apiTrack}';

        // Send each location to the server
        for (var location in locations) {
          try {
            // Prepare request body (exclude 'id' from API payload)
            final requestBody = Map<String, dynamic>.from(location);
            requestBody.remove('id');

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
                // If response is not JSON, log as string
                responseBodyStr = response.body;
              }

              // Log everything in a single, readable format
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

              developer.log(logMessage, name: 'SyncIsolateService');
            } catch (logError) {
              developer.log(
                'API Call Logging Error (Isolate)\nURL: $url\nMethod: POST\nStatus Code: ${response.statusCode}\nRequest Body: ${requestBody.toString()}\nResponse Body (Raw): ${response.body}\nLogging Error: ${logError.toString()}',
                name: 'SyncIsolateService',
                error: logError,
              );
            }

            if (response.statusCode >= 200 && response.statusCode < 300) {
              syncedCount++;
              syncedIds.add(location['id'] as int);
            } else {
              failedCount++;
            }
          } catch (e) {
            failedCount++;
            final requestBodyStr = const JsonEncoder.withIndent(
              '  ',
            ).convert(location);
            developer.log(
              'API POST Error (Isolate)\nURL: $url\nRequest Body:\n$requestBodyStr\nError: ${e.toString()}',
              name: 'SyncIsolateService',
              error: e,
            );
          }
        }

        // Send result back to main isolate
        resultPort.send({
          'success': true,
          'syncedCount': syncedCount,
          'failedCount': failedCount,
          'syncedIds': syncedIds,
        });
      } catch (e) {
        developer.log(
          'Sync Isolate Error',
          name: 'SyncIsolateService',
          error: {'Error': e.toString()},
        );
        resultPort.send({'success': false, 'error': e.toString()});
      }
    }
  }
}

/// Service to handle background sync using isolates
class SyncIsolateService {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;

  /// Initialize the isolate
  Future<void> initialize() async {
    if (_isolate != null) return;

    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(syncIsolateEntry, _receivePort!.sendPort);

    _sendPort = await _receivePort!.first as SendPort;
  }

  /// Sync locations in background isolate
  /// Returns a Future that completes with sync result
  Future<Map<String, dynamic>> syncLocations(
    List<Map<String, dynamic>> locations,
  ) async {
    if (_sendPort == null) {
      await initialize();
    }

    final resultPort = ReceivePort();
    final completer = Completer<Map<String, dynamic>>();

    resultPort.listen((result) {
      completer.complete(result as Map<String, dynamic>);
      resultPort.close();
    });

    // Send locations to isolate for processing
    _sendPort!.send({
      'locations': locations,
      'resultPort': resultPort.sendPort,
    });

    return completer.future;
  }

  /// Dispose the isolate
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    _isolate = null;
    _sendPort = null;
    _receivePort = null;
  }
}
