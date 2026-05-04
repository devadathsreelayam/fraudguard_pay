import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'payment_success_screen.dart';

class UpiPinScreen extends StatefulWidget {
  final Contact contact;
  final String amount;
  final String note;
  final bool isCheckingBalance; // Add this flag

  const UpiPinScreen({
    super.key,
    required this.contact,
    required this.amount,
    required this.note,
    this.isCheckingBalance = false, // Default is false (payment mode)
  });

  @override
  State<UpiPinScreen> createState() => _UpiPinScreenState();
}

class _UpiPinScreenState extends State<UpiPinScreen> {
  // final TextEditingController _pinController = TextEditingController();
  String _pin = "";
  int _attempts = 0;
  final int _maxAttempts = 3;

  void _onKeyTap(String value) {
    if (_pin.length < 4) {
      setState(() {
        _pin += value;
      });
      // if (_pin.length == 4) {
      //   _handleVerification();
      // }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _onOk() {
    if (_pin.length == 4) {
      _handleVerification();
    } else {
      Fluttertoast.showToast(msg: "Please enter a 4-digit PIN");
    }
  }

  void _handleVerification() async {
    if (_pin == "1234") {
      // Correct PIN Logic
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      if (widget.isCheckingBalance) {
        _showBalanceWindow();
      } else {
        _navigateToSuccess();
      }
    } else {
      // Incorrect PIN Logic
      _attempts++;
      int remaining = _maxAttempts - _attempts;

      if (_attempts >= _maxAttempts) {
        _handleFinalFailure();
      } else {
        setState(() => _pin = ""); // Clear dots
        Fluttertoast.showToast(
          msg: "Incorrect PIN. $remaining attempts left.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  void _handleFinalFailure() {
    Fluttertoast.showToast(
      msg: "Too many failed attempts. Transaction failed.",
    );

    // If checking balance, just go back. If payment, you could go to a Failure Screen.
    if (widget.isCheckingBalance) {
      Navigator.pop(context);
    } else {
      // Option A: Just go back to the previous screen
      Navigator.pop(context);
    }
  }

  void _navigateToSuccess() async {
    // Ensure contact has an ID before proceeding
    Contact contactToUse = widget.contact;

    if (contactToUse.id == null) {
      final dbHelper = DatabaseHelper();
      final newId = await dbHelper.insertContact(contactToUse);
      contactToUse = Contact(
        id: newId,
        name: contactToUse.name,
        vpa: contactToUse.vpa,
        phone: contactToUse.phone,
      );
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder:
            (_) => PaymentSuccessScreen(
              contact: contactToUse, // Now has valid ID
              amount: widget.amount,
              note: widget.note,
            ),
      ),
      (route) => route.isFirst,
    );
  }

  void _showBalanceWindow() {
    showModalBottomSheet(
      context: context,
      isDismissible: false, // Prevents closing by tapping outside
      enableDrag: false, // Prevents sliding it down manually
      backgroundColor: Colors.transparent, // Allow custom shape/color
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1E3A6F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Wrap content height
            children: [
              // Decorative Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                "Account Balance",
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                "₹1,24,500.00",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Savings Account •••• 1234",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // Primary Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close BottomSheet
                    Navigator.pop(context); // Return to Money Screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "DONE",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16), // Padding for bottom safety
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Enter UPI PIN",
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // Header showing recipient and amount
          _buildTopBar(),
          const Spacer(),

          // PIN Visualization (Dots)
          const Text(
            "ENTER 4-DIGIT PIN",
            style: TextStyle(letterSpacing: 2, color: Colors.blueGrey),
          ),
          const SizedBox(height: 20),
          _buildPinDots(),

          const Spacer(),

          // Custom Numeric Keypad
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildKeyboard(),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "To: ${widget.contact.name}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            "₹${widget.amount}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        bool isFilled = index < _pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? Colors.black87 : Colors.grey[300],
            border: Border.all(
              color: isFilled ? Colors.black87 : Colors.grey[400]!,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildKeyboard() {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      color: const Color(0xFFF2F2F2),
      padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 0),
      child: Column(
        children: [
          _buildKeyboardRow(['1', '2', '3']),
          _buildKeyboardRow(['4', '5', '6']),
          _buildKeyboardRow(['7', '8', '9']),
          _buildKeyboardRow(['backspace', '0', 'ok']),
        ],
      ),
    );
  }

  Widget _buildKeyboardRow(List<dynamic> keys) {
    return Row(
      children:
          keys.map((key) {
            return Expanded(
              child: InkWell(
                onTap: () {
                  if (key == 'backspace') {
                    _onBackspace();
                  } else if (key == 'ok') {
                    _onOk();
                  } else if (key != null) {
                    _onKeyTap(key);
                  }
                },
                child: Container(
                  height: 70,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12, width: 0.5),
                  ),
                  child: _buildKeyChild(key),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildKeyChild(dynamic key) {
    if (key == 'backspace')
      return const Icon(Icons.backspace_outlined, color: Colors.black54);
    if (key == 'ok') return const Icon(Icons.check, color: Colors.black54);
    if (key == null) return const SizedBox.shrink();
    return Text(
      key,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }
}
