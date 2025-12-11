class Env {
  // API Configuration
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://itlfmspocapi.infotracktelematics.com:4007/infobike',
  );

  static const String apiAuthLogin = '/api/Auth/UserLogin';
  static const String apiTrack = '/api/Track';
  static const String apiDashboard = '/api/Track/Dashboard';

  // Google Maps API Key - Read from environment variable
  // Set via: flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
  // Or build: flutter build apk --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '', // Empty default - must be provided via --dart-define
  );

  // App Configuration
  static const String appName = 'Cycle Tracking App';
  static const String appVersion = '1.0.0';
}
