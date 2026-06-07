import 'package:flutter/material.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/services/user_manager.dart';
import 'package:fraudguard_pay/widgets/theme.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fraudguard_pay/screens/debug/debug_database_screen.dart';
import 'package:fraudguard_pay/services/fraud_api_service.dart';
import 'package:fraudguard_pay/utils/settings_manager.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'User';
  String _userVpa = 'user@fgpay';
  String _userPhone = '+91 0000000000';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final name = await UserManager.getUserName();
    final vpa = await UserManager.getUserVpa();
    final phone = await UserManager.getUserPhone();

    setState(() {
      _userName = name;
      _userVpa = vpa;
      _userPhone = phone;
      _isLoading = false;
    });
  }

  String getInitials() {
    if (_userName == 'User') return 'U';
    return _userName.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: primaryDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Profile Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: accentOrange,
                  child: Text(
                    "U",
                    style: TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _userPhone,
                        style: TextStyle(color: textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showQrCodePopup(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: secondaryDark,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.qr_code,
                                color: accentOrange,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "Show QR",
                                style: TextStyle(
                                  color: accentOrange,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: borderColor),

          // 2. Options List
          Expanded(
            child: ListView(
              children: [
                _buildProfileTile(
                  Icons.account_balance_wallet,
                  "Bank Accounts",
                  () {},
                ),
                _buildProfileTile(Icons.payment, "Payment Settings", () {}),
                _buildProfileTile(Icons.security, "Security & Privacy", () {}),
                _buildProfileTile(Icons.help_outline, "Help & Feedback", () {}),
                _buildProfileTile(
                  Icons.settings_remote,
                  "API Configuration",
                  () => _showApiConfigDialog(context),
                ),
                _buildProfileTile(Icons.code, "Update Database", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DebugDatabaseScreen(),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                // In ProfileScreen, update the logout button:
                _buildProfileTile(Icons.logout, "Sign Out", () async {
                  // Show confirmation dialog
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Sign Out'),
                          content: const Text(
                            'Are you sure you want to sign out?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                  );

                  if (confirm == true) {
                    // Clear all user data
                    await UserManager.logout();

                    // Clear all cached data from database
                    // final dbHelper = DatabaseHelper();
                    // await dbHelper.clearAllData();

                    // Navigate to login screen and remove all previous routes
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        'login',
                        (route) => false,
                      );
                    }
                  }
                }, isDestructive: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: isDestructive ? Colors.redAccent : textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(color: isDestructive ? Colors.redAccent : textPrimary),
      ),
      trailing: const Icon(Icons.chevron_right, color: textSecondary),
    );
  }

  void _showQrCodePopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: primaryDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "My QR Code",
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: "upi://pay?pa=username@fgpay&pn=User%20Name",
                    size: 220,
                    version: QrVersions.auto,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "username@fgpay",
                  style: TextStyle(color: textPrimary, fontSize: 16),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentOrange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.share, color: Colors.white),
                    label: const Text(
                      "Share QR Code",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showApiConfigDialog(BuildContext context) {
    final TextEditingController endpointController = TextEditingController();
    String connectionStatus = 'Unknown';
    bool isTesting = false;
    String currentEndpoint = '';

    // Load current endpoint
    SettingsManager.getApiEndpoint().then((endpoint) {
      endpointController.text = endpoint;
      currentEndpoint = endpoint;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'API Endpoint Configuration',
                style: TextStyle(color: textPrimary),
              ),
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Full API Endpoint URL',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: endpointController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'http://192.168.1.100:8000/api/predict/',
                      hintStyle: const TextStyle(color: textSecondary),
                      filled: true,
                      fillColor: primaryDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: accentOrange),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              isTesting
                                  ? null
                                  : () async {
                                    setState(() => isTesting = true);
                                    final endpoint =
                                        endpointController.text.trim();
                                    if (endpoint.isEmpty) {
                                      Fluttertoast.showToast(
                                        msg: 'Please enter an endpoint URL',
                                      );
                                      setState(() => isTesting = false);
                                      return;
                                    }
                                    try {
                                      final isHealthy =
                                          await FraudApiService.testConnection(
                                            endpoint,
                                          );
                                      if (isHealthy) {
                                        connectionStatus = 'Connected ✓';
                                        Fluttertoast.showToast(
                                          msg: '✅ Connection successful!',
                                          backgroundColor: Colors.green,
                                        );
                                      } else {
                                        connectionStatus = 'Failed ✗';
                                        Fluttertoast.showToast(
                                          msg:
                                              '❌ Connection failed. Check URL and server.',
                                          backgroundColor: Colors.red,
                                        );
                                      }
                                    } catch (e) {
                                      connectionStatus = 'Failed ✗';
                                      Fluttertoast.showToast(
                                        msg: 'Error: $e',
                                        backgroundColor: Colors.red,
                                      );
                                    }
                                    setState(() => isTesting = false);
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentOrange,
                          ),
                          child:
                              isTesting
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Text('Test Connection'),
                        ),
                      ),
                    ],
                  ),
                  if (connectionStatus != 'Unknown') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            connectionStatus.contains('Connected')
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            connectionStatus.contains('Connected')
                                ? Icons.check_circle
                                : Icons.error,
                            color:
                                connectionStatus.contains('Connected')
                                    ? Colors.green
                                    : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            connectionStatus,
                            style: TextStyle(
                              color:
                                  connectionStatus.contains('Connected')
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: secondaryDark.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📱 Example endpoint formats:',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Android Emulator:\n  http://10.0.2.2:8000/api/predict/',
                          style: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• Physical Device (same WiFi):\n  http://192.168.1.100:8000/api/predict/',
                          style: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• Dummy endpoint for testing:\n  http://192.168.1.100:8000/api/predict-dummy/',
                          style: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final endpoint = endpointController.text.trim();
                    if (endpoint.isEmpty) {
                      Fluttertoast.showToast(
                        msg: 'Please enter an endpoint URL',
                      );
                      return;
                    }
                    // Test again before saving
                    final isHealthy = await FraudApiService.testConnection(
                      endpoint,
                    );
                    if (isHealthy) {
                      await SettingsManager.setApiEndpoint(endpoint);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      Fluttertoast.showToast(
                        msg: '✅ API endpoint saved successfully!',
                        backgroundColor: Colors.green,
                      );
                    } else {
                      Fluttertoast.showToast(
                        msg: '❌ Cannot save. Connection test failed.',
                        backgroundColor: Colors.red,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentOrange,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
