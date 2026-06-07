import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/services/api_service.dart';
import 'package:fraudguard_pay/services/sync_manager.dart';
import 'package:fraudguard_pay/services/user_manager.dart';
import 'package:fraudguard_pay/screens/navigation/main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final ApiService _api = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;
  bool _obscurePin = true;

  Future<void> _login() async {
    final userId = _userIdController.text.trim();
    final pin = _pinController.text.trim();

    if (userId.isEmpty) {
      Fluttertoast.showToast(msg: 'User ID required');
      return;
    }
    if (pin.isEmpty) {
      Fluttertoast.showToast(msg: 'PIN required');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _api.login(userId: userId, pin: pin);

      if (result['success'] == true) {
        final data = result['data'];
        final customerId = data['customer_id'];
        final userName = data['profile']['name'] ?? 'User';

        String userVpa = 'user@fgpay';
        if (data['profile'] != null && data['profile']['vpa'] != null) {
          userVpa = data['profile']['vpa'];
        }

        String userPhone = '+91 0000000000';
        if (data['user'] != null && data['user']['phone'] != null) {
          userPhone = data['user']['phone'];
        } else if (data['profile'] != null &&
            data['profile']['phone'] != null) {
          userPhone = data['profile']['phone'];
        }

        // STEP 1: Clear all existing local data before syncing new user data
        await _clearLocalData();

        // STEP 2: Save new user information
        await UserManager.setCustomerId(customerId);
        await UserManager.setUserName(userName);
        await UserManager.setUserVpa(userVpa);
        await UserManager.setUserPhone(userPhone);

        // STEP 3: Sync fresh data from server
        await SyncManager().syncOnLaunch(customerId);

        if (mounted) {
          Fluttertoast.showToast(msg: '✅ Login successful!');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          );
        }
      } else {
        Fluttertoast.showToast(msg: result['error'] ?? 'Invalid credentials');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Clear all local database data before syncing new user data
  Future<void> _clearLocalData() async {
    try {
      // Clear all tables
      await _dbHelper.clearAllData();
      print('✅ Local database cleared successfully');
    } catch (e) {
      print('❌ Error clearing local database: $e');
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
            const FlutterLogo(size: 80),
            const SizedBox(height: 40),
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                hintText: 'Enter your User ID (CUST_001)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              obscureText: _obscurePin,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'PIN',
                hintText: 'Enter your 4-digit PIN',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePin ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscurePin = !_obscurePin),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _showTestAccountsDialog();
              },
              child: const Text('Test Accounts'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTestAccountsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Test Accounts'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer Accounts:'),
                SizedBox(height: 8),
                Text('• CUST_001 (PIN: 1234)'),
                Text('• CUST_002 (PIN: 1234)'),
                Text('• CUST_003 (PIN: 1234)'),
                SizedBox(height: 16),
                Text('Merchant Accounts:'),
                SizedBox(height: 8),
                Text('• MERCH_001 (PIN: 1234)'),
                Text('• MERCH_002 (PIN: 1234)'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}
