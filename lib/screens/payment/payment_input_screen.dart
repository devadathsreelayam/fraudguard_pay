/// Amount entry screen with contact avatar for payments.
/// Flows: Payment Detail Screen → Payment Input Screen → UPI PIN Screen
import 'package:flutter/material.dart';
import 'package:fraudguard_pay/config/theme.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'upi_pin_screen.dart';

import 'package:fraudguard_pay/services/fraud_api_service.dart';
import 'package:fraudguard_pay/utils/settings_manager.dart';
import 'package:fluttertoast/fluttertoast.dart';

class PaymentInputScreen extends StatefulWidget {
  final Contact contact;
  final String amount;
  const PaymentInputScreen({
    super.key,
    required this.contact,
    this.amount = "0",
  });

  @override
  State<PaymentInputScreen> createState() => _PaymentInputScreenState();
}

class _PaymentInputScreenState extends State<PaymentInputScreen> {
  late TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.amount);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: secondaryDark,
              radius: 40,
              child: Text(
                widget.contact.name[0].toUpperCase(),
                style: const TextStyle(color: accentOrange, fontSize: 40),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Paying ${widget.contact.name}",
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _amountController,
              autofocus: widget.amount.isEmpty || widget.amount == "0",
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                prefix: const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text(
                    "₹",
                    style: TextStyle(color: Colors.white, fontSize: 48),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                hintText: "0",
                hintStyle: const TextStyle(color: Colors.white24),
                border: InputBorder.none,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _noteController,
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: "Add a note",
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
              ),
            ),
            const Spacer(),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amountText = _amountController.text;
                      if (amountText.isEmpty) return;

                      final amount = double.tryParse(amountText) ?? 0.0;
                      if (amount <= 0) {
                        Fluttertoast.showToast(
                          msg: 'Please enter a valid amount',
                        );
                        return;
                      }

                      // Check if fraud detection is enabled
                      final fraudCheckEnabled =
                          await SettingsManager.isFraudCheckEnabled();
                      if (fraudCheckEnabled) {
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder:
                              (_) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                        );

                        try {
                          // Prepare data for API (you need to compute/send required features)
                          final transactionData = {
                            'user_id':
                                'CUST_019998', // Replace with actual logged-in user ID
                            'merchant_vpa': widget.contact.vpa,
                            'device_id':
                                'DEV_035189', // Replace with actual device fingerprint
                            'amount': amount,
                            'timestamp': DateTime.now().toIso8601String(),
                            'user_location':
                                'Home', // Replace with actual location or customer home
                            'network_type': '4G', // Replace with actual network
                          };
                          // In a real app, you'd collect all 22 features from database.
                          // For demo, we assume the API will compute missing features or use defaults.
                          final api = FraudApiService();
                          final result = await api.checkTransaction(
                            transactionData,
                          );
                          Navigator.pop(context); // dismiss loader

                          if (result['success'] == true) {
                            final decision = result['decision'];
                            final riskScore = result['risk_score'];
                            final reasons = result['reasons'] as List? ?? [];

                            if (decision == 'FRAUD' || riskScore >= 0.7) {
                              // High risk – block transaction, show details
                              await showDialog(
                                context: context,
                                builder:
                                    (_) => AlertDialog(
                                      title: Row(
                                        children: const [
                                          Icon(
                                            Icons.warning,
                                            color: Colors.red,
                                          ),
                                          SizedBox(width: 8),
                                          Text('High Risk Transaction'),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Risk Score: ${(riskScore * 100).toStringAsFixed(1)}%',
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Reasons:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          ...reasons.map(
                                            (r) => Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                                top: 4,
                                              ),
                                              child: Text(
                                                '• ${r['label']}: ${r['value']}',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: const Text(
                                            'OK',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              );
                              return; // Block payment
                            } else if (decision == 'REVIEW') {
                              // Medium risk – show warning with option to continue
                              final continuePayment = await showDialog<bool>(
                                context: context,
                                builder:
                                    (_) => AlertDialog(
                                      title: const Text(
                                        '⚠️ Suspicious Transaction',
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Risk Score: ${(riskScore * 100).toStringAsFixed(1)}%',
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'This transaction has some risk factors:',
                                          ),
                                          ...reasons.map(
                                            (r) => Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                                top: 4,
                                              ),
                                              child: Text(
                                                '• ${r['label']}: ${r['value']}',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Do you still want to proceed?',
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                          ),
                                          child: const Text('Proceed Anyway'),
                                        ),
                                      ],
                                    ),
                              );
                              if (continuePayment != true) return;
                            } else {
                              // Low risk – show toast and proceed
                              Fluttertoast.showToast(
                                msg: '✅ Low risk transaction, proceeding...',
                              );
                            }
                          } else {
                            Navigator.pop(context);
                            Fluttertoast.showToast(
                              msg: 'Fraud check failed: ${result['error']}',
                            );
                            return;
                          }
                        } catch (e) {
                          Navigator.pop(context);
                          Fluttertoast.showToast(
                            msg: 'Error connecting to fraud service: $e',
                          );
                          return;
                        }
                      }

                      // If fraud check disabled or passed, go to PIN screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => UpiPinScreen(
                                contact: widget.contact,
                                amount: amountText,
                                note: _noteController.text,
                              ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Proceed to Pay",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
