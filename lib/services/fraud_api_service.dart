import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fraudguard_pay/utils/settings_manager.dart';

/// services/fraud_api_service.dart

class FraudApiService {
  Future<Map<String, dynamic>> checkTransaction(
    Map<String, dynamic> transactionData,
  ) async {
    final endpoint = await SettingsManager.getApiEndpoint();
    if (endpoint.isEmpty) {
      throw Exception(
        'API endpoint not configured. Please set it in Profile > API Configuration.',
      );
    }
    final url = Uri.parse(endpoint);
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(transactionData),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to check fraud: ${response.statusCode}');
    }
  }

  static Future<bool> testConnection(String endpoint) async {
    try {
      // Extract base URL for health check
      final uri = Uri.parse(endpoint);
      final baseUrl = '${uri.scheme}://${uri.host}:${uri.port}';
      final healthUrl = Uri.parse('$baseUrl/api/health/');
      final response = await http
          .get(healthUrl)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
