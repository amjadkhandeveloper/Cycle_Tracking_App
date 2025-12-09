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
              Map<String, dynamic>? responseBody;
              try {
                responseBody =
                    jsonDecode(response.body) as Map<String, dynamic>;
              } catch (e) {
                responseBody = {'raw': response.body};
              }

              developer.log(
                'API Call (Isolate): POST $url',
                name: 'SyncIsolateService',
                error: {
                  'URL': url,
                  'Method': 'POST',
                  'Status Code': response.statusCode,
                  'Request Body': requestBody,
                  'Response Body': responseBody,
                },
              );
            } catch (logError) {
              developer.log(
                'API Call Logging Error (Isolate)',
                name: 'SyncIsolateService',
                error: {
                  'URL': url,
                  'Method': 'POST',
                  'Status Code': response.statusCode,
                  'Request Body': requestBody,
                  'Response Body (Raw)': response.body,
                  'Logging Error': logError.toString(),
                },
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
            developer.log(
              'API POST Error (Isolate)',
              name: 'SyncIsolateService',
              error: {
                'URL': url,
                'Request Body': location,
                'Error': e.toString(),
              },
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
