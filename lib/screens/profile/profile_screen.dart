import 'package:flutter/material.dart';
import 'package:fraudguard_pay/widgets/theme.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fraudguard_pay/screens/debug/debug_database_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
                      const Text(
                        "User Name",
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "+91 9988774455",
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
                _buildProfileTile(Icons.code, "Update Database", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DebugDatabaseScreen(),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                _buildProfileTile(
                  Icons.logout,
                  "Sign Out",
                  () {},
                  isDestructive: true,
                ),
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
      isScrollControlled: true, // 1. Allows the sheet to size correctly
      backgroundColor: primaryDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return SafeArea(
          // 2. Wraps content to respect phone's navigation bar
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              24,
              24,
              24,
              16,
            ), // Adjust padding
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle Bar
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

                // Enhanced QR Container
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

                // Share button - now pushed above the navigation bar
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
}
