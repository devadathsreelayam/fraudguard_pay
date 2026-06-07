import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// services/user_manager.dart

class UserManager {
  static const String _customerIdKey = 'customer_id';
  static const String _deviceIdKey = 'device_id';
  static const String _userNameKey = 'user_name';
  static const String _userVpaKey = 'user_vpa'; // Add VPA storage
  static const String _userPhoneKey = 'user_phone';

  static Future<String?> getCustomerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customerIdKey);
  }

  static Future<void> setCustomerId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customerIdKey, id);
  }

  static Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
  }

  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey) ?? 'User';
  }

  static Future<void> setUserVpa(String vpa) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userVpaKey, vpa);
  }

  static Future<String> getUserVpa() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userVpaKey) ?? 'user@fgpay';
  }

  static Future<void> setUserPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPhoneKey, phone);
  }

  static Future<String> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userPhoneKey) ?? '+91 0000000000';
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customerIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_deviceIdKey);
    await prefs.remove(_userVpaKey);
    await prefs.remove(_userPhoneKey);

    // Clear database as well
    final dbHelper = DatabaseHelper();
    await dbHelper.clearAllData();
  }

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null) {
      deviceId = await _generateDeviceId();
      await prefs.setString(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  static Future<String> _generateDeviceId() async {
    final uuid = Uuid();
    return 'DEV_${uuid.v4().substring(0, 8).toUpperCase()}';
  }
}
