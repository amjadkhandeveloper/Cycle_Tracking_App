import 'api_service.dart';
import 'database_service.dart';
import 'sync_isolate_service.dart';
import '../config/env.dart';

class TrackingService {
  final ApiService _apiService = ApiService();
  final DatabaseService _databaseService = DatabaseService();
  final SyncIsolateService _syncIsolateService = SyncIsolateService();

  /// Send single location to /api/Track endpoint
  Future<void> sendSingleLocation(Map<String, dynamic> location) async {
    try {
      // Send single location to /api/Track endpoint
      await _apiService.post(Env.apiTrack, location);
    } catch (e) {
      rethrow;
    }
  }

  /// Sync pending locations using isolate (background processing)
  Future<int> syncPendingLocationsWithRetry() async {
    int totalSynced = 0;
    int maxRetries = 3;
    int retryDelay = 5; // seconds

    // Initialize isolate service
    await _syncIsolateService.initialize();

    // Keep syncing until all data is sent or max retries reached
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // Get all unsynced locations (up to 50 at a time for batch processing)
        final locations = await _databaseService.getUnsyncedLocations(
          limit: 50,
        );

        if (locations.isEmpty) {
          // All data synced successfully
          return totalSynced;
        }

        // Prepare location data with IDs for tracking
        final locationDataList = locations.map((loc) {
          return {
            'id': loc['id'] as int,
            'device_id':
                loc['user_id'] as String, // loc['device_id'] as String,
            'user_id': loc['user_id'] as String,
            'Vehicle_No': loc['vehicle_no'] as String? ?? '',
            'lat': loc['latitude'] as double,
            'lng': loc['longitude'] as double,
            'speed': (loc['speed'] as num?)?.toInt() ?? 0,
            'accuracy': (loc['accuracy'] as num?)?.toInt() ?? 0,
            'battery': loc['battery'] as int? ?? 0,
            'timestamp': _formatTimestamp(loc['timestamp'] as int),
          };
        }).toList();

        // Sync using isolate (background processing)
        final result = await _syncIsolateService.syncLocations(
          locationDataList,
        );

        if (result['success'] == true) {
          final syncedIds = result['syncedIds'] as List<int>;
          if (syncedIds.isNotEmpty) {
            // Mark as synced only after successful API call
            await _databaseService.markAsSynced(syncedIds);
            totalSynced += syncedIds.length;
          }
        }

        // Check if there are more unsynced locations
        final remaining = await _databaseService.getUnsyncedLocations();
        if (remaining.isEmpty) {
          // All data synced successfully
          return totalSynced;
        }

        // If there are still unsynced locations and not last attempt, wait and retry
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: retryDelay));
          retryDelay *= 2; // Exponential backoff
        }
      } catch (e) {
        // If error occurs, wait and retry
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: retryDelay));
          retryDelay *= 2;
        } else {
          // Last attempt failed, return what was synced so far
          return totalSynced;
        }
      }
    }

    return totalSynced;
  }

  Future<void> syncPendingLocations() async {
    await syncPendingLocationsWithRetry();
  }

  Future<void> saveLocationToDatabase({
    required String deviceId,
    required String userId,
    required double latitude,
    required double longitude,
    String? vehicleNo,
    int speed = 0,
    int accuracy = 0,
    int battery = 0,
  }) async {
    await _databaseService.insertLocation(
      deviceId: deviceId,
      userId: userId,
      vehicleNo: vehicleNo,
      latitude: latitude,
      longitude: longitude,
      speed: speed,
      accuracy: accuracy,
      battery: battery,
    );
  }

  /// Format timestamp from milliseconds to ISO 8601 string
  String _formatTimestamp(int timestampMs) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    return dateTime.toUtc().toIso8601String();
  }
}
