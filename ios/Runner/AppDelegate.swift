import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Google Maps with API Key from Info.plist
    // The API key is set in Info.plist by the build script (ios/scripts/load_api_key.sh)
    // which reads from ios/local.properties
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String,
       !apiKey.isEmpty && apiKey != "$(GOOGLE_MAPS_API_KEY)" {
      GMSServices.provideAPIKey(apiKey)
      print("✓ Google Maps API Key loaded successfully")
    } else {
      print("⚠ WARNING: Google Maps API Key not found in Info.plist!")
      print("   Run: ./ios/scripts/load_api_key.sh before building")
      print("   Or set GOOGLE_MAPS_API_KEY in ios/local.properties")
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
