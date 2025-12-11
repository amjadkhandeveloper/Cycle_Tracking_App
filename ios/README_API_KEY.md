# iOS Google Maps API Key Setup

This iOS app reads the Google Maps API key from `ios/local.properties` file.

## Setup Instructions

1. **Copy the example file** (if you haven't already):
   ```bash
   cp ios/local.properties.example ios/local.properties
   ```

2. **Add your Google Maps API Key** to `ios/local.properties`:
   ```
   GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY_HERE
   ```

3. **Generate the xcconfig file** (runs automatically during `pod install`, or run manually):
   ```bash
   ./ios/scripts/load_api_key.sh
   ```

4. **Build and run** your app:
   ```bash
   flutter run
   ```

## How It Works

- The script `ios/scripts/load_api_key.sh` reads `GOOGLE_MAPS_API_KEY` from `ios/local.properties`
- It generates `ios/Flutter/GoogleMapsAPIKey.xcconfig` with the API key
- The xcconfig file is included in `Debug.xcconfig` and `Release.xcconfig`
- `Info.plist` uses `$(GOOGLE_MAPS_API_KEY)` which gets populated from the xcconfig file
- `AppDelegate.swift` reads the API key from `Info.plist` and initializes Google Maps

## Important Notes

- `ios/local.properties` is gitignored and won't be committed to version control
- `ios/Flutter/GoogleMapsAPIKey.xcconfig` is auto-generated and also gitignored
- The script runs automatically during `pod install` via the Podfile's `post_install` hook
- If you change the API key in `local.properties`, run the script again or reinstall pods

