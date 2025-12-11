import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/location_service.dart';
import '../../services/tracking_service.dart';
import '../../services/database_service.dart';
import '../../services/device_service.dart';
import '../../services/user_preferences_service.dart';
import '../../services/dashboard_isolate_service.dart';
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
  final DeviceService _deviceService = DeviceService();
  final UserPreferencesService _userPreferencesService =
      UserPreferencesService();
  final DashboardIsolateService _dashboardIsolateService =
      DashboardIsolateService();

  String? _deviceId;
  String? _userId;
  String? _vehicleNo;

  GoogleMapController? _mapController;
  Position? _currentPosition;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _pollingTimer; // Timer for polling every minute
  Timer? _permissionCheckTimer;
  Timer? _retrySyncTimer;
  Timer? _dashboardTimer; // Timer for dashboard API calls every 5 minutes
  bool _isTracking = false;
  bool _hasLocationPermission = false;
  bool _isLocationServiceEnabled = false;
  bool _isLoadingLocation = true;
  DateTime? _lastUpdateTime;

  // Event data (will be updated from API)
  String eventName = 'Swadeshi Jagaran Cyclothon';
  DateTime? eventStartDate;
  DateTime? eventEndDate;

  // Markers for vehicles
  Set<Marker> _vehicleMarkers = {};
  BitmapDescriptor? _ambulanceIcon; // vehicleStatus 1
  BitmapDescriptor? _bicycleIcon; // vehicleStatus 0
  BitmapDescriptor? _carIcon; // vehicleStatus 2
  BitmapDescriptor? _logoIcon; // vehicleStatus 3

  // List of ambulances from dashboard API
  List<Map<String, dynamic>> _ambulanceList = [];

  @override
  void initState() {
    super.initState();
    // Initialize asynchronously with error handling
    _initializeDeviceAndUser().catchError((error) {
      debugPrint('Error initializing device and user: $error');
    });
    _initializeLocationSequentially().catchError((error) {
      debugPrint('Error initializing location: $error');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    });

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
                _updateUserMarker(); // Update user marker
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
    try {
      // Get device ID
      _deviceId = await _deviceService.getDeviceId();

      // Get user ID from preferences or from widget.userData
      if (widget.userData != null && widget.userData!['userid'] != null) {
        _userId = widget.userData!['userid']?.toString();
      } else {
        _userId = await _userPreferencesService.getUserId();
      }

      // Get vehicle number
      _vehicleNo = await _userPreferencesService.getVehicleNo();

      debugPrint(
        'Device ID: $_deviceId, User ID: $_userId, Vehicle No: $_vehicleNo',
      );

      // Initialize dashboard isolate service
      await _dashboardIsolateService.initialize();

      // Load custom icons
      await _loadCustomIcons();

      // Fetch dashboard data immediately
      _fetchDashboardData();

      // Set up timer to fetch dashboard data every 5 minutes
      _dashboardTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
        _fetchDashboardData();
      });
    } catch (e) {
      debugPrint('Error in _initializeDeviceAndUser: $e');
      // Set defaults to prevent null errors
      _deviceId ??= 'unknown-device';
      _userId ??= 'unknown-user';
      _vehicleNo ??= 'NA';
    }
  }

  /// Load custom icons based on vehicle status
  /// 0 - Other User (ic_bycycle)
  /// 1 - Ambulance (ic_ambulance)
  /// 2 - Vehicle (ic_car)
  /// 3 - Active user (ic_logo)
  Future<void> _loadCustomIcons() async {
    try {
      _bicycleIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/ic_bycycle.png',
      );
      _ambulanceIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/ic_ambulance.png',
      );
      _carIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/ic_car.png',
      );
      _logoIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/ic_logo.png',
      );
    } catch (e) {
      debugPrint('Error loading custom icons: $e');
      // Fallback to default markers if icons fail to load
    }
  }

  /// Fetch dashboard data from API
  Future<void> _fetchDashboardData() async {
    if (_userId == null || _vehicleNo == null) {
      debugPrint('Cannot fetch dashboard data: userId or vehicleNo is null');
      return;
    }

    try {
      final result = await _dashboardIsolateService.fetchDashboardData(
        userId: _userId!,
        vehicleNo: _vehicleNo!,
      );

      if (mounted && result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;

        // Update event dates
        if (data['event_Start_Date'] != null) {
          try {
            final startDateStr = data['event_Start_Date'] as String;
            eventStartDate = DateTime.parse(startDateStr);
          } catch (e) {
            debugPrint('Error parsing event start date: $e');
          }
        }

        if (data['event_End_Date'] != null) {
          try {
            final endDateStr = data['event_End_Date'] as String;
            eventEndDate = DateTime.parse(endDateStr);
          } catch (e) {
            debugPrint('Error parsing event end date: $e');
          }
        }

        // Parse vehicle data and create markers
        if (data['data'] != null && data['data'] is List) {
          final vehicles = data['data'] as List<dynamic>;
          _updateVehicleMarkers(vehicles);

          // Extract ambulance list
          _updateAmbulanceList(vehicles);
        }

        if (mounted) {
          setState(() {
            // State updated, markers will be rebuilt
          });
        }
      } else {
        debugPrint('Dashboard API call failed: ${result['error']}');
      }
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
    }
  }

  /// Update ambulance list from dashboard data
  void _updateAmbulanceList(List<dynamic> vehicles) {
    final List<Map<String, dynamic>> ambulanceList = [];

    for (var vehicle in vehicles) {
      try {
        final vehicleStatus = vehicle['vehicleStatus'] as int? ?? -1;
        final vehicleNo = vehicle['vehicleNo'] as String? ?? '';
        final driverMobileNo = vehicle['driverMobileNo'] as String? ?? '';

        // Only include ambulances (vehicleStatus == 1)
        if (vehicleStatus == 1 && driverMobileNo.isNotEmpty) {
          ambulanceList.add({
            'vehicleNo': vehicleNo,
            'driverMobileNo': driverMobileNo,
          });
        }
      } catch (e) {
        debugPrint('Error parsing ambulance data: $e');
      }
    }

    if (mounted) {
      setState(() {
        _ambulanceList = ambulanceList;
      });
    }
  }

  /// Update user marker on the map
  void _updateUserMarker() {
    if (_currentPosition == null || _logoIcon == null) {
      return;
    }

    final userMarker = Marker(
      markerId: const MarkerId('user_current_position'),
      position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      icon: _logoIcon!,
      infoWindow: const InfoWindow(
        title: 'Your Location',
        snippet: 'Active user',
      ),
    );

    // Update markers set
    final updatedMarkers = Set<Marker>.from(_vehicleMarkers);
    // Remove old user marker if exists
    updatedMarkers.removeWhere(
      (marker) => marker.markerId.value == 'user_current_position',
    );
    // Add new user marker
    updatedMarkers.add(userMarker);

    if (mounted) {
      setState(() {
        _vehicleMarkers = updatedMarkers;
      });
    }
  }

  /// Update vehicle markers on the map
  void _updateVehicleMarkers(List<dynamic> vehicles) {
    final Set<Marker> newMarkers = {};

    for (var vehicle in vehicles) {
      try {
        final vehicleNo = vehicle['vehicleNo'] as String? ?? '';
        final vehicleStatus = vehicle['vehicleStatus'] as int? ?? -1;
        final lat = vehicle['lat'] as double?;
        final lon = vehicle['lon'] as double?;
        final location = vehicle['location'] as String? ?? '';
        final speed = vehicle['speed'] as int? ?? 0;

        if (lat == null || lon == null) {
          continue; // Skip invalid coordinates
        }

        // Determine icon based on vehicleStatus
        // 0 - Other User (ic_bycycle)
        // 1 - Ambulance (ic_ambulance)
        // 2 - Vehicle (ic_car)
        // 3 - Active user (ic_logo)
        BitmapDescriptor icon;
        switch (vehicleStatus) {
          case 0: // Other User
            icon =
                _bicycleIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                );
            break;
          case 1: // Ambulance
            icon =
                _ambulanceIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
            break;
          case 2: // Vehicle/Car
            icon =
                _carIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
            break;
          case 3: // Active user
            icon =
                _logoIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                );
            break;
          default:
            // Fallback to bicycle icon for unknown status
            icon =
                _bicycleIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                );
        }

        // Create marker
        final marker = Marker(
          markerId: MarkerId(vehicleNo),
          position: LatLng(lat, lon),
          icon: icon,
          infoWindow: InfoWindow(
            title: vehicleNo,
            snippet: location.isNotEmpty
                ? '$location\nSpeed: $speed km/h'
                : 'Speed: $speed km/h',
          ),
        );

        newMarkers.add(marker);
      } catch (e) {
        debugPrint('Error creating marker for vehicle: $e');
      }
    }

    // Add user's current position as a marker with vehicleStatus 3 icon (ic_logo)
    if (_currentPosition != null && _logoIcon != null) {
      final userMarker = Marker(
        markerId: const MarkerId('user_current_position'),
        position: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        icon: _logoIcon!,
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'Active user',
        ),
      );
      newMarkers.add(userMarker);
    }

    if (mounted) {
      setState(() {
        _vehicleMarkers = newMarkers;
      });
    }
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
          _updateUserMarker(); // Update user marker
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
        _updateUserMarker(); // Update user marker
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
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          15.0, // Focus on user position with zoom level 15
        ),
      );
    }
  }

  /// Zoom in on the map
  void _zoomIn() {
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.zoomIn());
    }
  }

  /// Zoom out on the map
  void _zoomOut() {
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.zoomOut());
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
    });

    try {
      // Poll location every 10 minutes and send immediately
      _pollingTimer = Timer.periodic(const Duration(minutes: 10), (
        timer,
      ) async {
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
            _updateUserMarker(); // Update user marker

            // Save location to database with all required fields
            await _saveLocation(position);

            // Send immediately to server after each poll (every 10 minutes)
            await _sendLocationImmediately(position);
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

      // Get initial location immediately and send
      try {
        final position = await _locationService.getCurrentLocation();
        if (mounted) {
          setState(() {
            _currentPosition = position;
            _lastUpdateTime = DateTime.now();
          });
          _updateMapCamera();
          _updateUserMarker(); // Update user marker
          await _saveLocation(position);
          // Send initial location immediately
          await _sendLocationImmediately(position);
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
    });
  }

  Future<void> _retrySyncUnsyncedData() async {
    if (!_isTracking) return;

    // Check if there's any unsynced data
    final unsynced = await _databaseService.getUnsyncedLocations();
    if (unsynced.isEmpty) return;

    // Try to sync unsynced data
    try {
      await _trackingService.syncPendingLocationsWithRetry();
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
    } catch (e) {
      debugPrint('Error saving location: $e');
      // Handle database errors gracefully
    }
  }

  Future<void> _handleSOS() async {
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Getting location and sending SOS...'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    }

    try {
      // Get fresh location
      final position = await _locationService.getCurrentLocation();

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _lastUpdateTime = DateTime.now();
        });
        _updateMapCamera();
        _updateUserMarker(); // Update user marker

        // Save location to database
        await _saveLocation(position);

        // Send immediately to tracking API
        await _sendLocationImmediately(position);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS signal sent successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Show ambulance call popup after sending SOS
          Future.delayed(const Duration(milliseconds: 500), () {
            _showAmbulanceCallPopup();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SOS failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('SOS error: $e');
    }
  }

  /// Show ambulance call popup - direct call if single ambulance, selection if multiple
  void _showAmbulanceCallPopup() {
    if (_ambulanceList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ambulances available at the moment'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // If only one ambulance, show direct call popup
    if (_ambulanceList.length == 1) {
      final ambulance = _ambulanceList[0];
      final vehicleNo = ambulance['vehicleNo'] as String;
      final driverMobileNo = ambulance['driverMobileNo'] as String;
      _showDirectAmbulanceCallDialog(vehicleNo, driverMobileNo);
      return;
    }

    // If multiple ambulances, show selection dialog
    _showAmbulanceSelectionDialog();
  }

  /// Show direct ambulance call dialog for single ambulance
  void _showDirectAmbulanceCallDialog(String vehicleNo, String driverMobileNo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.local_hospital, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text(
              'Call Ambulance',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_hospital,
                color: Colors.red,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              vehicleNo,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone, size: 20, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  driverMobileNo,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _callAmbulance(driverMobileNo);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone, size: 20),
                SizedBox(width: 8),
                Text('Call Now', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show ambulance selection dialog for multiple ambulances
  void _showAmbulanceSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.local_hospital, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text(
              'Select Ambulance',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _ambulanceList.length,
            itemBuilder: (context, index) {
              final ambulance = _ambulanceList[index];
              final vehicleNo = ambulance['vehicleNo'] as String;
              final driverMobileNo = ambulance['driverMobileNo'] as String;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () => _callAmbulance(driverMobileNo),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.local_hospital,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicleNo,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    driverMobileNo,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// Call ambulance - copy number and open dial pad
  Future<void> _callAmbulance(String phoneNumber) async {
    try {
      // Copy phone number to clipboard
      await Clipboard.setData(ClipboardData(text: phoneNumber));

      // Open dial pad
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot open dial pad. Phone number copied: $phoneNumber',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Close dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phone number copied: $phoneNumber'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error calling ambulance: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Send location immediately to tracking API
  Future<void> _sendLocationImmediately(Position position) async {
    try {
      // Ensure device_id and user_id are available
      _deviceId ??= await _deviceService.getDeviceId();
      final userId =
          await _userPreferencesService.getUserId() ??
          widget.userData?['userid']?.toString();

      // Get vehicle number from preferences or userData
      final vehicleNo =
          await _userPreferencesService.getVehicleNo() ??
          widget.userData?['vehicleno']?.toString();

      // Get battery level
      final batteryLevel = await _deviceService.getBatteryLevel();

      // Prepare location data in the same format as tracking API
      final locationData = {
        'device_id': userId ?? 'NA', //_deviceId ?? 'unknown-device',
        'user_id': userId ?? 'NA',
        'Vehicle_No': vehicleNo ?? 'NA',
        'lat': position.latitude,
        'lng': position.longitude,
        'speed': position.speed.round(),
        'accuracy': position.accuracy.round(),
        'battery': batteryLevel,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      // Send immediately to tracking API
      await _trackingService.sendSingleLocation(locationData);
    } catch (e) {
      debugPrint('Error sending location immediately: $e');
      // Don't throw - let it fail silently and be synced later
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Format date as DD-MMM-YYYY (e.g., "13-Dec-2025")
  String _formatEventDate(DateTime dateTime) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = months[dateTime.month - 1];
    final year = dateTime.year.toString();
    return '$day-$month-$year';
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

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _pollingTimer?.cancel();
    _permissionCheckTimer?.cancel();
    _retrySyncTimer?.cancel();
    _dashboardTimer?.cancel();
    _dashboardIsolateService.dispose();
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
                                          dateTime:
                                              eventStartDate ??
                                              DateTime(2025, 3, 1, 8, 0),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildDateTimeInfo(
                                          icon: Icons.stop,
                                          label: 'End',
                                          dateTime:
                                              eventEndDate ??
                                              DateTime(2025, 3, 1, 18, 0),
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
                              : Stack(
                                  children: [
                                    GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target: LatLng(
                                          _currentPosition!.latitude,
                                          _currentPosition!.longitude,
                                        ),
                                        zoom: 15,
                                      ),
                                      onMapCreated: (controller) {
                                        _mapController = controller;
                                        // Focus on user position when map is created
                                        if (_currentPosition != null) {
                                          Future.delayed(
                                            const Duration(milliseconds: 300),
                                            () {
                                              _updateMapCamera();
                                            },
                                          );
                                        }
                                      },
                                      myLocationEnabled: false,
                                      myLocationButtonEnabled: false,
                                      markers: _vehicleMarkers,
                                    ),
                                    // Fullscreen button overlay
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Material(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        elevation: 4,
                                        child: InkWell(
                                          onTap: _showFullscreenMap,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            child: const Icon(
                                              Icons.fullscreen,
                                              color: Colors.deepPurple,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Zoom controls overlay
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Column(
                                        children: [
                                          const SizedBox(
                                            height: 48,
                                          ), // Space for fullscreen button
                                          Material(
                                            color: Colors.white,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(8),
                                                  topRight: Radius.circular(8),
                                                ),
                                            elevation: 4,
                                            child: InkWell(
                                              onTap: _zoomIn,
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topLeft: Radius.circular(8),
                                                    topRight: Radius.circular(
                                                      8,
                                                    ),
                                                  ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                child: const Icon(
                                                  Icons.add,
                                                  color: Colors.deepPurple,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            height: 1,
                                            color: Colors.grey.shade300,
                                          ),
                                          Material(
                                            color: Colors.white,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  bottomLeft: Radius.circular(
                                                    8,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    8,
                                                  ),
                                                ),
                                            elevation: 4,
                                            child: InkWell(
                                              onTap: _zoomOut,
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    bottomLeft: Radius.circular(
                                                      8,
                                                    ),
                                                    bottomRight:
                                                        Radius.circular(8),
                                                  ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                child: const Icon(
                                                  Icons.remove,
                                                  color: Colors.deepPurple,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Last Update
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Location: ${_formatLastUpdate()}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
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
                                            ? 'Location captured and sent every 10 minutes'
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
            _formatEventDate(dateTime),
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

  /// Show fullscreen map
  void _showFullscreenMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullscreenMapScreen(
          vehicleMarkers: _vehicleMarkers,
          currentPosition: _currentPosition,
          logoIcon: _logoIcon,
        ),
      ),
    );
  }
}

/// Fullscreen map screen
class _FullscreenMapScreen extends StatefulWidget {
  final Set<Marker> vehicleMarkers;
  final Position? currentPosition;
  final BitmapDescriptor? logoIcon;

  const _FullscreenMapScreen({
    required this.vehicleMarkers,
    this.currentPosition,
    this.logoIcon,
  });

  @override
  State<_FullscreenMapScreen> createState() => _FullscreenMapScreenState();
}

class _FullscreenMapScreenState extends State<_FullscreenMapScreen> {
  GoogleMapController? _fullscreenMapController;

  void _focusOnUserPosition() {
    if (_fullscreenMapController == null || widget.currentPosition == null) {
      return;
    }

    try {
      _fullscreenMapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(
            widget.currentPosition!.latitude,
            widget.currentPosition!.longitude,
          ),
          15.0, // Focus on user position with zoom level 15
        ),
      );
    } catch (e) {
      debugPrint('Error focusing on user position: $e');
    }
  }

  /// Zoom in on the fullscreen map
  void _zoomIn() {
    if (_fullscreenMapController != null) {
      _fullscreenMapController!.animateCamera(CameraUpdate.zoomIn());
    }
  }

  /// Zoom out on the fullscreen map
  void _zoomOut() {
    if (_fullscreenMapController != null) {
      _fullscreenMapController!.animateCamera(CameraUpdate.zoomOut());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.currentPosition != null
                  ? LatLng(
                      widget.currentPosition!.latitude,
                      widget.currentPosition!.longitude,
                    )
                  : const LatLng(0, 0),
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _fullscreenMapController = controller;
              // Focus on user position when map is created
              Future.delayed(const Duration(milliseconds: 300), () {
                _focusOnUserPosition();
              });
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            markers: widget.vehicleMarkers,
          ),
          // Close button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.topRight,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  elevation: 4,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.fullscreen_exit,
                        color: Colors.deepPurple,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Zoom controls overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.topRight,
                child: Column(
                  children: [
                    const SizedBox(height: 48), // Space for close button
                    Material(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      elevation: 4,
                      child: InkWell(
                        onTap: _zoomIn,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.add,
                            color: Colors.deepPurple,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    Container(height: 1, color: Colors.grey.shade300),
                    Material(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      elevation: 4,
                      child: InkWell(
                        onTap: _zoomOut,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.remove,
                            color: Colors.deepPurple,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fullscreenMapController?.dispose();
    super.dispose();
  }
}
