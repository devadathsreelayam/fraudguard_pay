import 'package:flutter/material.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:fraudguard_pay/models/app_state_model.dart';
import 'package:lottie/lottie.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final Contact contact;
  final String amount;
  final String note;

  const PaymentSuccessScreen({
    super.key,
    required this.contact,
    required this.amount,
    required this.note,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool _showDoneButton = false;

  @override
  void initState() {
    super.initState();
    _storeTransaction();

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showDoneButton = true;
        });
      }
    });
  }

  Future<void> _storeTransaction() async {
    Contact contactToUse = widget.contact;

    // Save contact if it doesn't have an ID
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

    final newTxn = Transaction(
      id: "TXN${DateTime.now().millisecondsSinceEpoch}",
      timestamp: DateTime.now(),
      senderContactId: 0,
      recipientContactId: widget.contact.id!,
      amount: double.tryParse(widget.amount) ?? 0.0,
      type: "Money Sent",
      status: "Success",
      note: widget.note,
    );

    setState(() {
      transactionHistory.insert(0, newTxn);
    });

    try {
      await DatabaseHelper().insertTransaction(newTxn);
    } catch (e) {
      debugPrint('Error saving successful payment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00C853),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.network(
              'https://assets10.lottiefiles.com/packages/lf20_pqnfmone.json',
              width: 200,
              repeat: false,
            ),
            const SizedBox(height: 20),
            const Text(
              "Payment Successful",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              child:
                  _showDoneButton
                      ? Column(
                        key: const ValueKey('detailsContent'),
                        children: [
                          const SizedBox(height: 10),
                          Text(
                            "₹${widget.amount} sent to ${widget.contact.name}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 40),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.green,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                                vertical: 14,
                              ),
                            ),
                            child: const Text("Done"),
                          ),
                        ],
                      )
                      : const SizedBox(height: 112),
            ),
          ],
        ),
      ),
    );
  }
}
