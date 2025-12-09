# Location Permissions Configuration

This document explains the location permissions required for the Cycle Tracking App on both Android and iOS platforms.

## Android Permissions

### Required Permissions (AndroidManifest.xml)

1. **ACCESS_FINE_LOCATION**
   - **Purpose**: Allows access to precise location (GPS)
   - **Required**: Yes, for accurate location tracking
   - **When Used**: When tracking is active

2. **ACCESS_COARSE_LOCATION**
   - **Purpose**: Allows access to approximate location (network-based)
   - **Required**: Yes, as fallback when GPS is unavailable
   - **When Used**: When GPS signal is weak or unavailable

3. **ACCESS_BACKGROUND_LOCATION** (Optional)
   - **Purpose**: Allows location access when app is in background
   - **Required**: Only if you need background tracking (Android 10+)
   - **Status**: Currently commented out - uncomment if needed
   - **Note**: Requires additional runtime permission request

4. **INTERNET**
   - **Purpose**: Required for API calls to sync location data
   - **Required**: Yes

### Android Runtime Permissions

The app requests location permissions at runtime using the `geolocator` package:
- **When**: When user tries to enable tracking
- **How**: Through `LocationService.hasLocationPermission()` and `getCurrentLocation()`
- **User Experience**: System dialog appears asking for permission

### Android API Level Requirements

- **Minimum SDK**: API 16 (Android 4.1) - Default Flutter requirement
- **Background Location**: Requires API 29+ (Android 10) for `ACCESS_BACKGROUND_LOCATION`
- **Recommended**: API 21+ (Android 5.0) for better location services

## iOS Permissions

### Required Permission Descriptions (Info.plist)

1. **NSLocationWhenInUseUsageDescription**
   - **Purpose**: Required for location access when app is in use
   - **Required**: Yes (Mandatory)
   - **Message**: "This app needs access to your location to track your cycling route and provide accurate location data for the Cycle Rally event."
   - **When Shown**: First time user enables tracking

2. **NSLocationAlwaysAndWhenInUseUsageDescription**
   - **Purpose**: Required for background location (iOS 11+)
   - **Required**: Yes, if you want background tracking
   - **Message**: "This app needs access to your location even when the app is in the background to continuously track your cycling route during the event."
   - **When Shown**: When requesting "Always" permission

3. **NSLocationAlwaysUsageDescription**
   - **Purpose**: Required for background location (iOS 10 and earlier)
   - **Required**: Yes, for backward compatibility
   - **Message**: Same as above
   - **When Shown**: On older iOS versions when requesting "Always" permission

### iOS Permission Flow

1. **First Request**: System shows dialog with `NSLocationWhenInUseUsageDescription`
2. **User Options**:
   - "Allow While Using App" - Grants `NSLocationWhenInUse`
   - "Don't Allow" - Denies permission
   - "Change to Always Allow" - Available in Settings

3. **Background Permission**: If app needs background location, user must grant "Always" permission in Settings

### iOS Version Requirements

- **Minimum**: iOS 8.0+ (Default Flutter requirement)
- **Background Location**: iOS 11+ for `NSLocationAlwaysAndWhenInUseUsageDescription`
- **Recommended**: iOS 13+ for better location services

## Permission Request Flow

### When Permissions Are Requested

1. **App Launch**: Checks if location permission is granted
2. **User Taps Tracking Switch**: Requests permission if not granted
3. **User Taps Tracking Card**: Shows dialog to enable location
4. **Location Service Error**: Prompts user to enable location

### User Experience

1. **Permission Dialog**: System-native dialog appears
2. **Permission Denied**: 
   - Android: User can enable in Settings
   - iOS: User can enable in Settings
3. **Permission Granted**: Tracking starts automatically
4. **Permission Revoked**: App detects and prompts user again

## Testing Permissions

### Android Testing

1. **Grant Permission**: 
   ```bash
   adb shell pm grant com.example.cycle_tracking_app android.permission.ACCESS_FINE_LOCATION
   adb shell pm grant com.example.cycle_tracking_app android.permission.ACCESS_COARSE_LOCATION
   ```

2. **Revoke Permission**:
   ```bash
   adb shell pm revoke com.example.cycle_tracking_app android.permission.ACCESS_FINE_LOCATION
   ```

3. **Test Permission Flow**: 
   - Revoke permissions
   - Launch app
   - Try to enable tracking
   - Verify permission dialog appears

### iOS Testing

1. **Reset Permissions**: Delete app and reinstall
2. **Test Permission Flow**:
   - Launch app
   - Try to enable tracking
   - Verify permission dialog appears with correct message
3. **Test Background Permission**: 
   - Grant "While Using App" first
   - Go to Settings > Privacy > Location Services > Cycle Tracking App
   - Change to "Always"

## Troubleshooting

### Android Issues

1. **Permission Not Requested**:
   - Check AndroidManifest.xml has permissions declared
   - Verify app is targeting API 23+ (runtime permissions required)

2. **Permission Denied Forever**:
   - User must enable in Settings > Apps > Cycle Tracking App > Permissions
   - App shows dialog to open Settings

### iOS Issues

1. **Permission Dialog Not Showing**:
   - Check Info.plist has all required keys
   - Verify keys are spelled correctly (case-sensitive)
   - Delete app and reinstall

2. **Background Location Not Working**:
   - Verify "Always" permission is granted in Settings
   - Check Info.plist has `NSLocationAlwaysAndWhenInUseUsageDescription`

## Additional Notes

- **Privacy**: Always explain why location is needed
- **User Control**: Allow users to disable tracking anytime
- **Battery**: Continuous location tracking can drain battery
- **Accuracy**: GPS accuracy depends on device and environment
- **Compliance**: Ensure compliance with privacy regulations (GDPR, etc.)

## References

- [Android Location Permissions](https://developer.android.com/training/location/permissions)
- [iOS Location Services](https://developer.apple.com/documentation/corelocation)
- [Geolocator Package](https://pub.dev/packages/geolocator)

