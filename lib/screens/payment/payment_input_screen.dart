/// Amount entry screen with contact avatar for payments.
/// Flows: Payment Detail Screen → Payment Input Screen → UPI PIN Screen
import 'package:flutter/material.dart';
import 'package:fraudguard_pay/config/theme.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'upi_pin_screen.dart';

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
                    onPressed: () {
                      if (_amountController.text.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => UpiPinScreen(
                                  contact: widget.contact,
                                  amount: _amountController.text,
                                  note: _noteController.text,
                                ),
                          ),
                        );
                      }
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
