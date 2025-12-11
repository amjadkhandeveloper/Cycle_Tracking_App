import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.cycle_tracking_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.cycle_tracking_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Read Google Maps API Key from local.properties or environment variable
        val localProperties = Properties()
        // local.properties is in the android/ directory
        // From android/app/build.gradle.kts, rootProject is android/
        val localPropertiesFile = rootProject.file("local.properties")
        if (localPropertiesFile.exists()) {
            FileInputStream(localPropertiesFile).use { stream ->
                localProperties.load(stream)
            }
        }
        val googleMapsApiKey = localProperties.getProperty("GOOGLE_MAPS_API_KEY") 
            ?: System.getenv("GOOGLE_MAPS_API_KEY")
            ?: ""
        
        // Debug: Print the API key status (first 10 chars only for security)
        if (googleMapsApiKey.isNotEmpty()) {
            println("✓ Google Maps API Key loaded successfully: ${googleMapsApiKey.take(10)}...")
        } else {
            println("⚠ WARNING: Google Maps API Key is empty! Check android/local.properties")
        }
        
        buildConfigField("String", "GOOGLE_MAPS_API_KEY", "\"$googleMapsApiKey\"")
        resValue("string", "google_maps_api_key", googleMapsApiKey)
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
