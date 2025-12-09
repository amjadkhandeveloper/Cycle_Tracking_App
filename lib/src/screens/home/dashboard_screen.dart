import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/location_service.dart';
import '../../services/tracking_service.dart';
import '../../services/database_service.dart';
import '../../services/api_service.dart';
import '../../services/device_service.dart';
import '../../services/user_preferences_service.dart';
import 'history_screen.dart';
import '../profile/cyclist_profile.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const DashboardScreen({super.key, this.userData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final LocationService _locationService = LocationService();
  final TrackingService _trackingService = TrackingService();
  final DatabaseService _databaseService = DatabaseService();
  final ApiService _apiService = ApiService();
  final DeviceService _deviceService = DeviceService();
  final UserPreferencesService _userPreferencesService =
      UserPreferencesService();

  String? _deviceId;
  String? _userId;

  GoogleMapController? _mapController;
  Position? _currentPosition;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _pollingTimer; // Timer for polling every minute
  Timer? _permissionCheckTimer;
  Timer? _retrySyncTimer;
  bool _isTracking = false;
  bool _hasLocationPermission = false;
  bool _isLocationServiceEnabled = false;
  bool _isLoadingLocation = true;
  DateTime? _lastUpdateTime;
  DateTime? _lastSyncTime;
  int _pendingSyncCount = 0;
  int _totalPollingCount = 0; // Total pollings captured
  int _pollingCounter = 0; // Counter for syncing every 10 pollings
  int _lastPollingBatchSize = 0;

  // Event data (temporary - will come from API)
  final String eventName = 'Cycle Rally 2025';
  final DateTime eventStartDate = DateTime(2025, 3, 1, 8, 0);
  final DateTime eventEndDate = DateTime(2025, 3, 1, 18, 0);

  @override
  void initState() {
    super.initState();
    _initializeDeviceAndUser();
    _loadPendingSyncCount();
    _initializeLocationSequentially();

    // Check permission status periodically
    _permissionCheckTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      final isEnabled = await _locationService.isLocationEnabled();
      final hasPermission = await _locationService.hasLocationPermission();
      if (mounted) {
        final needsUpdate =
            isEnabled != _isLocationServiceEnabled ||
            hasPermission != _hasLocationPermission;
        if (needsUpdate) {
          setState(() {
            _isLocationServiceEnabled = isEnabled;
            _hasLocationPermission = hasPermission;
          });

          // Automatically start tracking if location becomes available
          if (hasPermission && isEnabled && !_isTracking) {
            // Try to get location and start tracking
            try {
              final position = await _locationService.getCurrentLocation();
              if (mounted) {
                setState(() {
                  _currentPosition = position;
                  _lastUpdateTime = DateTime.now();
                });
                _updateMapCamera();
                _startTracking();
              }
            } catch (e) {
              debugPrint('Error getting location: $e');
            }
          } else if ((!hasPermission || !isEnabled) && _isTracking) {
            // Automatically stop tracking if location becomes unavailable
            _stopTracking();
            setState(() {
              _currentPosition = null;
            });
          }
        }
      }
    });
  }

  Future<void> _initializeDeviceAndUser() async {
    // Get device ID
    _deviceId = await _deviceService.getDeviceId();

    // Get user ID from preferences or from widget.userData
    if (widget.userData != null && widget.userData!['userid'] != null) {
      _userId = widget.userData!['userid']?.toString();
    } else {
      _userId = await _userPreferencesService.getUserId();
    }

    debugPrint('Device ID: $_deviceId, User ID: $_userId');
  }

  Future<void> _initializeLocationSequentially() async {
    setState(() {
      _isLoadingLocation = true;
    });

    // Step 1: Check if location service is enabled
    final isEnabled = await _locationService.isLocationEnabled();
    if (!isEnabled) {
      if (mounted) {
        setState(() {
          _isLocationServiceEnabled = false;
          _hasLocationPermission = false;
          _isLoadingLocation = false;
          _currentPosition = null;
        });
        // Show dialog to enable location service
        _showLocationServiceDisabledDialog();
      }
      return;
    }

    // Step 2: Location service is enabled, now check permission
    setState(() {
      _isLocationServiceEnabled = true;
    });

    final permission = await _locationService.checkPermission();

    if (permission == LocationPermission.denied) {
      // Request permission
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
        _showLocationPermissionRequestDialog();
      }
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      // Permission permanently denied, show settings dialog
      if (mounted) {
        setState(() {
          _hasLocationPermission = false;
          _isLoadingLocation = false;
          _currentPosition = null;
        });
        _showLocationPermissionDeniedForeverDialog();
      }
      return;
    }

    // Step 3: Permission granted, get location
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      try {
        final position = await _locationService.getCurrentLocation();
        if (mounted) {
          setState(() {
            _currentPosition = position;
            _lastUpdateTime = DateTime.now();
            _hasLocationPermission = true;
            _isLocationServiceEnabled = true;
            _isLoadingLocation = false;
          });
          _updateMapCamera();
          // Automatically start tracking when location is available
          _startTracking();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _hasLocationPermission = false;
            _isLoadingLocation = false;
            _currentPosition = null;
          });
          // Stop tracking if location fails
          if (_isTracking) {
            _stopTracking();
          }
          debugPrint('Location initialization error: $e');
        }
      }
    }
  }

  void _showLocationServiceDisabledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Location services are disabled on your device. Please enable location services in your device settings to continue using this app.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _locationService.openLocationSettings();
              // Wait a bit and check again
              await Future.delayed(const Duration(seconds: 1));
              if (mounted) {
                _initializeLocationSequentially();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showLocationPermissionRequestDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Location Permission Required'),
        content: const Text(
          'This app needs access to your location to track your cycling route and provide accurate location data. Please allow location access when prompted.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _requestLocationPermission();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Allow Location'),
          ),
        ],
      ),
    );
  }

  void _showLocationPermissionDeniedForeverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Location Permission Denied'),
        content: const Text(
          'Location permission has been permanently denied. Please enable location permission in app settings to use this feature.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
              // Wait a bit and check again
              await Future.delayed(const Duration(seconds: 1));
              if (mounted) {
                _initializeLocationSequentially();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open App Settings'),
          ),
        ],
      ),
    );
  }

  void _showLocationPermissionDialog() {
    _showLocationPermissionRequestDialog();
  }

  Future<void> _requestLocationPermission() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // First check if location service is enabled
      final isEnabled = await _locationService.isLocationEnabled();
      if (!isEnabled) {
        if (mounted) {
          setState(() {
            _isLocationServiceEnabled = false;
            _isLoadingLocation = false;
          });
          _showLocationServiceDisabledDialog();
        }
        return;
      }

      // Request permission explicitly
      final permission = await _locationService.checkPermission();
      LocationPermission newPermission = permission;

      if (permission == LocationPermission.denied) {
        newPermission = await Geolocator.requestPermission();
      }

      if (newPermission == LocationPermission.denied ||
          newPermission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _hasLocationPermission = false;
            _isLoadingLocation = false;
          });
          if (newPermission == LocationPermission.deniedForever) {
            _showLocationPermissionDeniedForeverDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Location permission denied. Please enable in app settings.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        return;
      }

      // Permission granted, get location
      final position = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _lastUpdateTime = DateTime.now();
          _hasLocationPermission = true;
          _isLocationServiceEnabled = true;
          _isLoadingLocation = false;
        });
        _updateMapCamera();
        // Automatically start tracking when location is available
        _startTracking();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location enabled successfully! Tracking started automatically.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });

        final errorMessage = e.toString();
        if (errorMessage.contains('disabled')) {
          _showLocationServiceDisabledDialog();
        } else if (errorMessage.contains('denied')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission denied. Please enable in app settings.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to get location: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _updateMapCamera() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    }
  }

  Future<void> _startTracking() async {
    if (_isTracking) return;

    // Check location permission first
    final hasPermission = await _locationService.hasLocationPermission();
    if (!hasPermission) {
      _showLocationPermissionDialog();
      return;
    }

    setState(() {
      _isTracking = true;
      _hasLocationPermission = true;
      _pollingCounter = 0; // Reset polling counter
    });

    try {
      // Poll location every minute
      _pollingTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
        if (!_isTracking) {
          timer.cancel();
          return;
        }

        try {
          // Get current location
          final position = await _locationService.getCurrentLocation();

          if (mounted) {
            setState(() {
              _currentPosition = position;
              _lastUpdateTime = DateTime.now();
            });
            _updateMapCamera();

            // Save location to database with all required fields
            await _saveLocation(position);

            // Increment polling counter
            setState(() {
              _pollingCounter++;
              _totalPollingCount++;
            });

            // Sync to server after every 10 pollings
            if (_pollingCounter >= 10) {
              _pollingCounter = 0; // Reset counter
              await _syncLocations();
            }
          }
        } catch (e) {
          debugPrint('Error polling location: $e');
          // Handle location errors gracefully
          if (mounted && e.toString().contains('permission')) {
            setState(() {
              _hasLocationPermission = false;
              _isTracking = false;
            });
            _stopTracking();
            _showLocationPermissionDialog();
          }
        }
      });

      // Start retry timer (every 2 minutes) - continuously retry syncing unsynced data
      _retrySyncTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
        _retrySyncUnsyncedData();
      });

      // Get initial location immediately
      try {
        final position = await _locationService.getCurrentLocation();
        if (mounted) {
          setState(() {
            _currentPosition = position;
            _lastUpdateTime = DateTime.now();
          });
          _updateMapCamera();
          await _saveLocation(position);
          setState(() {
            _pollingCounter++;
            _totalPollingCount++;
          });
        }
      } catch (e) {
        debugPrint('Error getting initial location: $e');
      }
    } catch (e) {
      setState(() {
        _isTracking = false;
        _hasLocationPermission = false;
      });
      _showLocationPermissionDialog();
    }
  }

  void _stopTracking() {
    _locationSubscription?.cancel();
    _pollingTimer?.cancel();
    _retrySyncTimer?.cancel();
    setState(() {
      _isTracking = false;
      _pollingCounter = 0; // Reset polling counter when stopped
    });
  }

  Future<void> _retrySyncUnsyncedData() async {
    if (!_isTracking) return;

    // Check if there's any unsynced data
    final unsynced = await _databaseService.getUnsyncedLocations();
    if (unsynced.isEmpty) return;

    // Try to sync unsynced data
    try {
      final countSynced = await _trackingService
          .syncPendingLocationsWithRetry();
      await _loadPendingSyncCount();

      if (mounted && countSynced > 0) {
        setState(() {
          _lastSyncTime = DateTime.now();
          _lastPollingBatchSize = countSynced;
        });
      }
    } catch (e) {
      debugPrint('Retry sync error: $e');
    }
  }

  Future<void> _saveLocation(Position position) async {
    try {
      // Ensure device_id is available
      _deviceId ??= await _deviceService.getDeviceId();

      // Get user_id from preferences or userData (consistent with vehicle_no)
      final userId =
          await _userPreferencesService.getUserId() ??
          widget.userData?['userid']?.toString();

      // Get vehicle number from preferences or userData
      final vehicleNo =
          await _userPreferencesService.getVehicleNo() ??
          widget.userData?['vehicleno']?.toString();

      // Get battery level
      final batteryLevel = await _deviceService.getBatteryLevel();

      // Extract location data from Position
      final latitude = position.latitude;
      final longitude = position.longitude;
      final speed = position.speed.round(); // Convert to int (in m/s)
      final accuracy = position.accuracy.round(); // Convert to int (in meters)

      // Save location to database with all required fields
      await _trackingService.saveLocationToDatabase(
        deviceId: _deviceId ?? 'unknown-device',
        userId: userId ?? 'NA',
        vehicleNo: vehicleNo ?? 'NA',
        latitude: latitude,
        longitude: longitude,
        speed: speed,
        accuracy: accuracy,
        battery: batteryLevel,
      );
      await _loadPendingSyncCount();
    } catch (e) {
      debugPrint('Error saving location: $e');
      // Handle database errors gracefully
    }
  }

  Future<void> _syncLocations() async {
    if (!_isTracking) return;

    try {
      // Get count of locations to be synced before sync
      final unsyncedBefore = await _databaseService.getUnsyncedLocations();
      final countToSync = unsyncedBefore.length;

      if (countToSync == 0) {
        // No data to sync
        return;
      }

      // Sync with retry logic - will retry until all data is sent
      final countSynced = await _trackingService
          .syncPendingLocationsWithRetry();
      await _loadPendingSyncCount();

      // Only update sync time if data was actually sent successfully
      if (mounted && countSynced > 0) {
        setState(() {
          _lastSyncTime = DateTime.now();
          _lastPollingBatchSize = countSynced;
        });
      }
    } catch (e) {
      // Error handled in tracking service
      if (mounted) {
        debugPrint('Sync error: $e');
      }
    }
  }

  Future<void> _loadPendingSyncCount() async {
    try {
      final unsynced = await _databaseService.getUnsyncedLocations();
      if (mounted) {
        setState(() {
          _pendingSyncCount = unsynced.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending sync count: $e');
      // Database might not be initialized yet, ignore error
    }
  }

  Future<void> _handleSOS() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _apiService.post('/api/SOS/Emergency', {
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'userid': widget.userData?['userid'],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS signal sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SOS failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatLastUpdate() {
    if (_lastUpdateTime == null) return 'Never';
    final now = DateTime.now();
    final difference = now.difference(_lastUpdateTime!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else {
      return _formatDateTime(_lastUpdateTime!);
    }
  }

  String _formatLastSync() {
    if (_lastSyncTime == null) return 'Never';
    final now = DateTime.now();
    final difference = now.difference(_lastSyncTime!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else {
      return _formatDateTime(_lastSyncTime!);
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _pollingTimer?.cancel();
    _permissionCheckTimer?.cancel();
    _retrySyncTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.userData?['username'] ?? 'User';
    final vehicleNo = widget.userData?['vehicleno'] ?? '';
    final mobileNo = widget.userData?['mobileno'] ?? '';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade700,
              Colors.deepPurple.shade400,
              Colors.blue.shade600,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header Section
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome, $username',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (vehicleNo.isNotEmpty)
                                        Text(
                                          'Vehicle: $vehicleNo',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                            fontWeight: FontWeight.w300,
                                          ),
                                        ),
                                      if (mobileNo.isNotEmpty)
                                        Text(
                                          'Mobile: $mobileNo',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white.withValues(
                                              alpha: 0.6,
                                            ),
                                            fontWeight: FontWeight.w300,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.history,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const HistoryScreen(),
                                          ),
                                        );
                                      },
                                      tooltip: 'View History',
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                CyclistProfile(
                                                  userData: widget.userData,
                                                ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.2,
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Event Info Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.event,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          eventName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDateTimeInfo(
                                          icon: Icons.play_arrow,
                                          label: 'Start',
                                          dateTime: eventStartDate,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildDateTimeInfo(
                                          icon: Icons.stop,
                                          label: 'End',
                                          dateTime: eventEndDate,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Map Section
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _isLoadingLocation
                              ? Container(
                                  color: Colors.grey.shade300,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : _currentPosition == null
                              ? Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isLocationServiceEnabled
                                              ? Icons.location_off
                                              : Icons.location_disabled,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _isLocationServiceEnabled
                                              ? 'Location permission required'
                                              : 'Location services disabled',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 32.0,
                                          ),
                                          child: Text(
                                            _isLocationServiceEnabled
                                                ? 'Please enable location permission to view map'
                                                : 'Please enable location services in device settings',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.8,
                                              ),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(
                                      _currentPosition!.latitude,
                                      _currentPosition!.longitude,
                                    ),
                                    zoom: 15,
                                  ),
                                  onMapCreated: (controller) {
                                    _mapController = controller;
                                  },
                                  myLocationEnabled: true,
                                  myLocationButtonEnabled: false,
                                  markers: {
                                    Marker(
                                      markerId: const MarkerId('user_location'),
                                      position: LatLng(
                                        _currentPosition!.latitude,
                                        _currentPosition!.longitude,
                                      ),
                                      icon:
                                          BitmapDescriptor.defaultMarkerWithHue(
                                            BitmapDescriptor.hueBlue,
                                          ),
                                    ),
                                  },
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Last Update & Sync Status
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Location: ${_formatLastUpdate()}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_pendingSyncCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.sync,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$_pendingSyncCount pending',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.cloud_upload,
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Last sync: ${_formatLastSync()}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (_lastSyncTime != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '(${_formatDateTime(_lastSyncTime!)})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.send,
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Polling: $_totalPollingCount',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (_isTracking && _pollingCounter > 0) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '($_pollingCounter/10)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                    if (_lastPollingBatchSize > 0) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '(+$_lastPollingBatchSize synced)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green.withValues(
                                            alpha: 0.8,
                                          ),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Tracking Status Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: InkWell(
                          onTap:
                              (!_hasLocationPermission ||
                                  !_isLocationServiceEnabled)
                              ? () {
                                  if (!_isLocationServiceEnabled) {
                                    _showLocationServiceDisabledDialog();
                                  } else {
                                    _showLocationPermissionDialog();
                                  }
                                }
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    (_hasLocationPermission &&
                                        _isLocationServiceEnabled)
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : Colors.orange.withValues(alpha: 0.5),
                                width:
                                    (_hasLocationPermission &&
                                        _isLocationServiceEnabled)
                                    ? 1
                                    : 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _isTracking
                                        ? Colors.green.withValues(alpha: 0.3)
                                        : (!_isLocationServiceEnabled)
                                        ? Colors.orange.withValues(alpha: 0.3)
                                        : _hasLocationPermission
                                        ? Colors.grey.withValues(alpha: 0.3)
                                        : Colors.orange.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _isTracking
                                        ? Icons.location_on
                                        : (!_isLocationServiceEnabled)
                                        ? Icons.location_disabled
                                        : _hasLocationPermission
                                        ? Icons.location_off
                                        : Icons.location_disabled,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isTracking
                                            ? 'Tracking Active'
                                            : (!_isLocationServiceEnabled)
                                            ? 'Location Services Disabled'
                                            : _hasLocationPermission
                                            ? 'Waiting for Location'
                                            : 'Location Permission Required',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _isTracking
                                            ? 'Location captured continuously, synced every 10 min'
                                            : (!_isLocationServiceEnabled)
                                            ? 'Tap to open device settings'
                                            : _hasLocationPermission
                                            ? 'Tracking will start automatically'
                                            : 'Tap to enable location permission',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Status indicator instead of switch
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isTracking
                                        ? Colors.green.withValues(alpha: 0.3)
                                        : Colors.grey.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _isTracking
                                              ? Colors.green
                                              : Colors.grey,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _isTracking ? 'ON' : 'OFF',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Fixed Footer - Powered by
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Powered by ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    Image.asset(
                      'assets/images/sponsor_logo.png',
                      height: 30,
                      errorBuilder: (context, error, stackTrace) {
                        return const Text(
                          'Infotrack',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleSOS,
            borderRadius: BorderRadius.circular(28),
            child: const Center(
              child: Text(
                "SOS",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeInfo({
    required IconData icon,
    required String label,
    required DateTime dateTime,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatDateTime(dateTime),
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
