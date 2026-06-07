// payment_success_screen.dart

import 'package:flutter/material.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:lottie/lottie.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final Contact contact;
  final String amount;
  final String note;
  final Transaction? transaction;

  const PaymentSuccessScreen({
    super.key,
    required this.contact,
    required this.amount,
    required this.note,
    this.transaction,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool _showDoneButton = false;

  @override
  void initState() {
    super.initState();

    // No database write here! Transaction is already saved with SUCCESS status
    // from the PIN screen. We just display it.

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showDoneButton = true;
        });
      }
    });
  }

  String _getDisplayAmount() {
    if (widget.transaction != null) {
      return "₹${widget.transaction!.amount.toStringAsFixed(2)}";
    }
    return "₹${widget.amount}";
  }

  String _getDisplayMessage() {
    if (widget.transaction != null) {
      if (widget.transaction!.isFraud) {
        return "⚠️ Payment completed with fraud warning";
      } else if (widget.transaction!.isReview) {
        return "⚠️ Payment completed under review";
      }
      return "Payment Successful";
    }
    return "Payment Successful";
  }

  Color _getBackgroundColor() {
    if (widget.transaction != null) {
      if (widget.transaction!.isFraud) {
        return Colors.orange.shade700;
      } else if (widget.transaction!.isReview) {
        return Colors.orange.shade600;
      }
    }
    return const Color(0xFF00C853);
  }

  IconData _getIcon() {
    if (widget.transaction != null) {
      if (widget.transaction!.isFraud || widget.transaction!.isReview) {
        return Icons.warning_amber_rounded;
      }
    }
    return Icons.check_circle_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Different animation for fraud cases
            if (widget.transaction?.isFraud == true ||
                widget.transaction?.isReview == true)
              Icon(_getIcon(), size: 100, color: Colors.white)
            else
              Lottie.network(
                'https://assets10.lottiefiles.com/packages/lf20_pqnfmone.json',
                width: 200,
                repeat: false,
              ),
            const SizedBox(height: 20),
            Text(
              _getDisplayMessage(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
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
                            "${_getDisplayAmount()} sent to ${widget.contact.name}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          if (widget.transaction?.note != null &&
                              widget.transaction!.note!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              "Note: ${widget.transaction!.note}",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (widget.transaction?.riskScore != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "Risk Score: ${(widget.transaction!.riskScore! * 100).toStringAsFixed(1)}%",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                          if (widget.transaction?.fraudStatus ==
                              Transaction.FRAUD_REVIEW) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "Transaction Flagged for Review",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          if (widget.transaction?.fraudStatus ==
                              Transaction.FRAUD_FRAUD) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "⚠️ Override Applied - Payment Processed",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 40),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _getBackgroundColor(),
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
