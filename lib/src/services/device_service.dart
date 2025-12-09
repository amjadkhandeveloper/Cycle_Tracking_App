import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'dart:io';

class DeviceService {
  static String? _cachedDeviceId;
  final Battery _battery = Battery();

  /// Get unique device ID
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        _cachedDeviceId = androidInfo.id; // Android ID
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        _cachedDeviceId = iosInfo.identifierForVendor ?? 'unknown-ios-device';
      } else {
        _cachedDeviceId = 'unknown-device';
      }

      return _cachedDeviceId ?? 'unknown-device';
    } catch (e) {
      // Fallback to a default value if device info fails
      _cachedDeviceId = 'unknown-device';
      return _cachedDeviceId!;
    }
  }

  /// Get current battery level (0-100)
  Future<int> getBatteryLevel() async {
    try {
      final batteryLevel = await _battery.batteryLevel;
      return batteryLevel;
    } catch (e) {
      // Return 0 if battery level cannot be determined
      return 0;
    }
  }
}
