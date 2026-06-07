// utils/settings_manager.dart

import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager {
  static const String _apiEndpointKey = 'api_endpoint';
  static const String _fraudCheckEnabledKey = 'fraud_check_enabled';

  // Default full endpoint
  static const String defaultApiEndpoint = 'http://192.168.1.8:5000';

  static Future<void> setApiEndpoint(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiEndpointKey, endpoint);
  }

  static Future<String> getApiEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiEndpointKey) ?? defaultApiEndpoint;
  }

  static Future<String> getBaseUrlFromEndpoint() async {
    final endpoint = await getApiEndpoint();
    // Extract base URL from endpoint (remove everything after the last '/api/')
    final apiIndex = endpoint.indexOf('/api/');
    if (apiIndex != -1) {
      return endpoint.substring(0, apiIndex);
    }
    // Fallback: try to parse as URL and get origin
    try {
      final uri = Uri.parse(endpoint);
      return '${uri.scheme}://${uri.host}:${uri.port}';
    } catch (e) {
      return endpoint;
    }
  }

  static Future<void> setFraudCheckEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fraudCheckEnabledKey, enabled);
  }

  static Future<bool> isFraudCheckEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_fraudCheckEnabledKey) ?? true;
  }
}
