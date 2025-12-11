# API Keys Setup Guide

This guide explains how to securely configure the Google Maps API key for this application.

## ⚠️ Security Notice

**Never commit API keys to version control!** The API key has been removed from the source code and must be configured locally.

## Setup Instructions

### Option 1: Using Flutter --dart-define (Recommended for Development)

Run the app with the API key as an environment variable:

```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_api_key_here
```

For building:

```bash
# Android APK
flutter build apk --dart-define=GOOGLE_MAPS_API_KEY=your_api_key_here

# Android App Bundle
flutter build appbundle --dart-define=GOOGLE_MAPS_API_KEY=your_api_key_here

# iOS
flutter build ios --dart-define=GOOGLE_MAPS_API_KEY=your_api_key_here
```

### Option 2: Using local.properties (Android)

1. Create or edit `android/local.properties` file:
```properties
GOOGLE_MAPS_API_KEY=your_api_key_here
```

2. The `local.properties` file is already in `.gitignore` and won't be committed.

### Option 3: Using Info.plist (iOS)

1. Open `ios/Runner/Info.plist`
2. Find the `GoogleMapsAPIKey` key
3. Replace `$(GOOGLE_MAPS_API_KEY)` with your actual API key, or set it via Xcode build settings

**Note:** For production iOS builds, consider using Xcode's build configuration to set environment variables securely.

## Getting Your Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the "Maps SDK for Android" and "Maps SDK for iOS" APIs
4. Go to "Credentials" → "Create Credentials" → "API Key"
5. Restrict the API key to your app's package name and bundle ID
6. Copy the API key and use it in the setup methods above

## Verification

After setting up the API key, verify it works by:
1. Running the app
2. Checking that the map loads correctly
3. Verifying no API key errors appear in the console

## Troubleshooting

- **Map not loading**: Check that the API key is correctly set and the Maps SDK APIs are enabled
- **Build errors**: Ensure the API key is set before building
- **iOS issues**: Make sure the API key is set in Info.plist or via build settings

