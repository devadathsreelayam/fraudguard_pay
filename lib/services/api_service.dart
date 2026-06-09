import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fraudguard_pay/utils/settings_manager.dart';

/// services/api_service.dart

class ApiService {
  static const String _basePath = '/api';

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final baseUrl = await SettingsManager.getApiEndpoint();
    final url = Uri.parse('$baseUrl$_basePath$endpoint');

    print('📤 POST $url');
    print('📦 Request: $data');

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 30));

    print('📥 Response ${response.statusCode}: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    final baseUrl = await SettingsManager.getApiEndpoint();
    final url = Uri.parse('$baseUrl$_basePath$endpoint');

    print('📤 GET $url');

    final response = await http.get(url).timeout(const Duration(seconds: 30));

    print('📥 Response ${response.statusCode}: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // 0. Login endpoint
  Future<Map<String, dynamic>> login({
    required String userId,
    required String pin,
  }) async {
    return await post('/login/', {'user_id': userId, 'pin': pin});
  }

  // 1. Register customer (for future use)
  Future<Map<String, dynamic>> registerCustomer({
    required String phone,
    required String name,
    required String deviceId,
  }) async {
    return await post('/customer/register/', {
      'phone': phone,
      'name': name,
      'device_id': deviceId,
    });
  }

  // 2. Resolve VPA
  Future<Map<String, dynamic>> resolveVpa(
    String vpa, {
    String? name,
    String type = 'MERCHANT',
  }) async {
    return await post('/resolve/', {'vpa': vpa, 'name': name, 'type': type});
  }

  // 3. Fraud prediction + create transaction
  Future<Map<String, dynamic>> predictTransaction({
    required String userId,
    required String deviceId,
    String? merchantVpa,
    String? recipientId,
    required double amount,
    required DateTime timestamp,
    required String userLocation,
    required String networkType,
    String transactionType = 'P2M',
    String? note,
  }) async {
    return await post('/predict-transaction/', {
      'user_id': userId,
      'device_id': deviceId,
      if (merchantVpa != null) 'merchant_vpa': merchantVpa,
      if (recipientId != null) 'recipient_id': recipientId,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'user_location': userLocation,
      'network_type': networkType,
      'transaction_type': transactionType,
      if (note != null) 'note': note,
    });
  }

  // 4. Update transaction status (after PIN)
  Future<Map<String, dynamic>> updateTransactionStatus({
    required String transactionId,
    required String status,
    required String userId,
  }) async {
    return await post('/transaction/update-status/', {
      'transaction_id': transactionId,
      'status': status,
      'user_id': userId,
    });
  }

  // 8. Override blocked transaction
  Future<Map<String, dynamic>> overrideTransaction({
    required String transactionId,
    required String userId,
    required String reason,
  }) async {
    return await post('/override/', {
      'transaction_id': transactionId,
      'user_id': userId,
      'reason': reason,
    });
  }

  // 5. Sync customer data (for caching)
  Future<Map<String, dynamic>> syncCustomerData(String userId) async {
    return await post('/customer/sync-data/', {'user_id': userId});
  }

  // 6. Health check
  Future<bool> healthCheck() async {
    try {
      final baseUrl = await SettingsManager.getApiEndpoint();
      final url = Uri.parse('$baseUrl/api/health/');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
