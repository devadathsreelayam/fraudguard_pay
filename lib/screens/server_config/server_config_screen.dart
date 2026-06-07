import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fraudguard_pay/services/api_service.dart';
import 'package:fraudguard_pay/utils/settings_manager.dart';
import 'package:fraudguard_pay/screens/login/login_screen.dart';

class ServerConfigScreen extends StatefulWidget {
  const ServerConfigScreen({super.key});

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final TextEditingController _urlController = TextEditingController();
  final ApiService _api = ApiService();
  bool _isTesting = false;
  String? _savedUrl;

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final url = await SettingsManager.getApiEndpoint();
    setState(() {
      _savedUrl = url;
      _urlController.text = url;
    });
  }

  Future<void> _testAndSave() async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter a server URL');
      return;
    }

    // Validate URL format
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      Fluttertoast.showToast(msg: 'URL must start with http:// or https://');
      return;
    }

    setState(() => _isTesting = true);

    try {
      // Save temporarily for testing
      await SettingsManager.setApiEndpoint(url);

      // Test connection
      final isHealthy = await _api.healthCheck();

      if (isHealthy) {
        Fluttertoast.showToast(msg: '✅ Server connected successfully!');

        if (mounted) {
          // Navigate to login screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: '❌ Cannot connect to server. Check URL and try again.',
        );
        // Revert to old URL if exists
        if (_savedUrl != null && _savedUrl!.isNotEmpty) {
          await SettingsManager.setApiEndpoint(_savedUrl!);
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e');
    } finally {
      setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings_remote, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            const Text(
              'Server Configuration',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please enter your backend server URL to continue',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://192.168.1.100:5000',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
                helperText:
                    _savedUrl != null &&
                            _savedUrl != SettingsManager.defaultApiEndpoint
                        ? 'Previously saved: $_savedUrl'
                        : null,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📱 Examples:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Android Emulator: http://10.0.2.2:5000',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  Text(
                    '• Physical Device (same WiFi): http://192.168.x.x:5000',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  Text(
                    '• iOS Simulator: http://localhost:5000',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Make sure your Flask/Django server is running!',
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isTesting ? null : _testAndSave,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child:
                    _isTesting
                        ? const CircularProgressIndicator()
                        : const Text(
                          'Connect & Continue',
                          style: TextStyle(fontSize: 16),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
