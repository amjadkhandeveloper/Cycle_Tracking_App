class Env {
  // API Configuration
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://itlfmspocapi.infotracktelematics.com:4007/infobike',
  );

  static const String apiAuthLogin = '/api/Auth/UserLogin';
  static const String apiTrack = '/api/Track';

  // Google Maps API Key
  static const String googleMapsApiKey =
      'AIzaSyA8N5KaAKdoanX7YOjltmwUb6_UisceH9k';

  // App Configuration
  static const String appName = 'Cycle Tracking App';
  static const String appVersion = '1.0.0';
}
