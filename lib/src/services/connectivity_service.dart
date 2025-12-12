import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connection
  /// Returns true if connected, false otherwise
  Future<bool> hasInternetConnection() async {
    try {
      // Check connectivity status
      final connectivityResults = await _connectivity.checkConnectivity();

      // If no connectivity at all, return false
      if (connectivityResults.isEmpty ||
          connectivityResults.contains(ConnectivityResult.none)) {
        return false;
      }

      // For mobile data and WiFi, verify actual internet connectivity
      // by attempting to connect to a reliable server
      if (connectivityResults.contains(ConnectivityResult.mobile) ||
          connectivityResults.contains(ConnectivityResult.wifi)) {
        try {
          // Try to connect to a reliable server (Google DNS)
          final result = await InternetAddress.lookup(
            'google.com',
          ).timeout(const Duration(seconds: 5));
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            return true;
          }
        } catch (e) {
          // Connection failed
          return false;
        }
      }

      // For other connectivity types (ethernet, etc.), assume connected
      return true;
    } catch (e) {
      // Error checking connectivity, assume no connection
      return false;
    }
  }

  /// Get current connectivity status
  Future<List<ConnectivityResult>> getConnectivityStatus() async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (e) {
      return [ConnectivityResult.none];
    }
  }

  /// Stream of connectivity changes
  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;
}
