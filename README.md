# Cycle Tracking App

A Flutter-based mobile application for tracking cyclists during events with real-time location monitoring, SOS functionality, and ambulance contact features.

## Features

### 🔐 Authentication
- **User Login**: Secure authentication via API
- **Automatic Login**: Stores user credentials locally for automatic login on subsequent app launches
- **User Data Storage**: Saves UserId, UserName, VehicleNo, and MobileNo locally

### 📍 Location Tracking
- **Real-time Location**: Continuous GPS tracking with high accuracy
- **Background Sync**: Isolate-based background synchronization to prevent UI blocking
- **Polling Interval**: Automatic location capture and sync every 10 minutes
- **SOS Button**: Immediate location capture and transmission on emergency
- **Location History**: View all tracked locations in history screen

### 🗺️ Map Features
- **Google Maps Integration**: Interactive map with custom markers
- **Vehicle Markers**: 
  - Ambulance markers (red icons)
  - Bicycle markers (green icons)
- **Auto-fit Bounds**: Map automatically adjusts to show all markers
- **Fullscreen Map**: Fullscreen view for better visibility
- **Real-time Updates**: Vehicle locations updated every 5 minutes via Dashboard API

### 🚑 Emergency Features
- **SOS Functionality**: 
  - Immediate location capture and API transmission
  - Automatic ambulance selection dialog
  - One-tap ambulance calling
- **Ambulance Contact**: 
  - List of available ambulances from Dashboard API
  - Display ambulance number and driver mobile number
  - Copy phone number to clipboard
  - Open device dial pad automatically

### 📊 Dashboard
- **Event Information**: 
  - Event name display
  - Event start and end dates (formatted as DD-MMM-YYYY)
- **Tracking Status**: Visual indicators for tracking state
- **Sync Status**: Pending sync count and last sync time
- **Location Updates**: Last location update time

### 💾 Data Management
- **Local Database**: SQLite database for offline location storage
- **Offline Support**: Locations saved locally when offline, synced when online
- **Data Persistence**: User preferences and location history stored locally

### 📱 Platform Support
- **Android**: Full support with native Google Maps integration
- **iOS**: Full support with native Google Maps integration
- **API Key Security**: API keys stored in local configuration files (not in source code)

## Technical Stack

- **Framework**: Flutter 3.9.2+
- **Language**: Dart
- **Maps**: Google Maps Flutter
- **Location**: Geolocator
- **Database**: SQLite (sqflite)
- **Storage**: Shared Preferences
- **HTTP**: http package
- **Background Processing**: Dart Isolates

## Project Structure

```
lib/
├── src/
│   ├── config/
│   │   └── env.dart              # Environment configuration
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart  # Login screen
│   │   │   └── splash_screen.dart # Splash screen with auto-login
│   │   ├── home/
│   │   │   ├── dashboard_screen.dart # Main dashboard
│   │   │   └── history_screen.dart   # Location history
│   │   └── profile/
│   │       └── cyclist_profile.dart  # User profile
│   └── services/
│       ├── api_service.dart           # HTTP API wrapper
│       ├── database_service.dart      # SQLite database operations
│       ├── device_service.dart        # Device ID and battery
│       ├── location_service.dart      # GPS location services
│       ├── tracking_service.dart      # Location tracking logic
│       ├── sync_isolate_service.dart  # Background sync isolate
│       ├── dashboard_isolate_service.dart # Dashboard API isolate
│       └── user_preferences_service.dart   # User data storage
```

## Setup Instructions

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Dart SDK
- Android Studio / Xcode (for platform-specific builds)
- Google Maps API Key

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd cycle_tracking_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Google Maps API Key**

   **For Android:**
   - Create `android/local.properties` file
   - Add: `GOOGLE_MAPS_API_KEY=your_api_key_here`
   - Or copy from `android/local.properties.example`

   **For iOS:**
   - Create `ios/local.properties` file
   - Add: `GOOGLE_MAPS_API_KEY=your_api_key_here`
   - Or copy from `ios/local.properties.example`
   - The API key will be automatically injected into `Info.plist` during build

4. **Configure API Base URL** (Optional)
   - Default API URL is set in `lib/src/config/env.dart`
   - To override, use: `flutter run --dart-define=API_BASE_URL=your_api_url`

5. **Run the app**
   ```bash
   flutter run
   ```

## API Configuration

### Base URL
Default: `http://itlfmspocapi.infotracktelematics.com:4007/infobike`

### Endpoints

1. **Login API**
   - Endpoint: `/api/Auth/UserLogin`
   - Method: POST
   - Request Body:
     ```json
     {
       "username": "string",
       "password": "string"
     }
     ```
   - Response: User data including UserId, UserName, VehicleNo, MobileNo

2. **Tracking API**
   - Endpoint: `/api/Track`
   - Method: POST
   - Request Body:
     ```json
     {
       "device_id": "string",
       "user_id": "string",
       "Vehicle_No": "string",
       "lat": number,
       "lng": number,
       "speed": number,
       "accuracy": number,
       "battery": number,
       "timestamp": "ISO8601 string"
     }
     ```

3. **Dashboard API**
   - Endpoint: `/api/Track/Dashboard`
   - Method: POST
   - Request Body:
     ```json
     {
       "user_id": "string",
       "vehicle_no": "string"
     }
     ```
   - Response: Event dates and vehicle locations (ambulances and bicycles)

## Key Features Implementation

### Background Sync
- Uses Dart isolates to prevent UI blocking during API calls
- Automatic retry mechanism for failed syncs
- Pending locations tracked and displayed

### Location Tracking
- High accuracy GPS tracking
- Speed and accuracy converted to integers
- Battery level included in tracking data
- Device ID and User ID included in all requests

### Automatic Login
- User credentials stored securely using SharedPreferences
- Splash screen checks for existing login
- Automatic navigation to dashboard if logged in

### SOS Functionality
- Immediate location capture
- Instant API transmission
- Ambulance selection dialog
- One-tap calling with clipboard copy

## Security Notes

- **API Keys**: Never commit `local.properties` files containing API keys
- **Credentials**: User credentials stored securely using SharedPreferences
- **Network**: All API calls use HTTPS (when configured)

## Build Instructions

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

## Troubleshooting

### Google Maps not displaying
1. Verify API key is correctly set in `local.properties`
2. Check API key restrictions in Google Cloud Console
3. Ensure API key has Maps SDK enabled for Android/iOS

### Location not updating
1. Check location permissions in device settings
2. Verify location services are enabled
3. Check app permissions in device settings

### API calls failing
1. Verify API base URL is correct
2. Check network connectivity
3. Review API logs in console/debug output

## Logging

All API calls are logged with:
- URL
- Request method
- Request body (formatted JSON)
- Response status code
- Response body (formatted JSON)

Logs can be viewed in:
- Flutter DevTools
- Console output (debug mode)
- Device logs (via `adb logcat` for Android)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

[Add your license here]

## Support

For issues and questions, please contact [your contact information]
