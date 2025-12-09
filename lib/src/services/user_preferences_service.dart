import 'package:shared_preferences/shared_preferences.dart';

class UserPreferencesService {
  static const String _keyUserId = 'user_id';
  static const String _keyUsername = 'username';
  static const String _keyMobileNo = 'mobile_no';
  static const String _keyVehicleNo = 'vehicle_no';

  /// Save user data after login
  Future<void> saveUserData({
    required String userId,
    String? username,
    String? mobileNo,
    String? vehicleNo,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
    if (username != null) {
      await prefs.setString(_keyUsername, username);
    }
    if (mobileNo != null) {
      await prefs.setString(_keyMobileNo, mobileNo);
    }
    if (vehicleNo != null) {
      await prefs.setString(_keyVehicleNo, vehicleNo);
    }
  }

  /// Get user ID
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  /// Get username
  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  /// Get mobile number
  Future<String?> getMobileNo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMobileNo);
  }

  /// Get vehicle number
  Future<String?> getVehicleNo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyVehicleNo);
  }

  /// Get all user data
  Future<Map<String, dynamic>?> getUserData() async {
    final userId = await getUserId();
    if (userId == null) return null;

    return {
      'userid': userId,
      'username': await getUsername(),
      'mobileno': await getMobileNo(),
      'vehicleno': await getVehicleNo(),
    };
  }

  /// Clear user data (logout)
  Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyMobileNo);
    await prefs.remove(_keyVehicleNo);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final userId = await getUserId();
    return userId != null && userId.isNotEmpty;
  }
}
