// fraud_warning_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/services/api_service.dart';
import 'package:fraudguard_pay/services/user_manager.dart';
import 'package:fluttertoast/fluttertoast.dart';

class FraudWarningScreen extends StatefulWidget {
  final Transaction transaction;
  final double riskScore;
  final List<dynamic> reasons;
  final String decision;
  final VoidCallback onProceed;
  final VoidCallback? onOverride; // Callback after successful override

  const FraudWarningScreen({
    super.key,
    required this.transaction,
    required this.riskScore,
    required this.reasons,
    required this.decision,
    required this.onProceed,
    this.onOverride,
  });

  @override
  State<FraudWarningScreen> createState() => _FraudWarningScreenState();
}

class _FraudWarningScreenState extends State<FraudWarningScreen> {
  int _countdown = 5;
  bool _canProceed = false;
  Timer? _timer;
  bool _isOverriding = false;
  bool _isOverridden = false; // Track if override was successful
  final TextEditingController _reasonController = TextEditingController();
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    if (widget.decision == Transaction.FRAUD_REVIEW) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdown > 1) {
            _countdown--;
          } else {
            _countdown = 0;
            _canProceed = true;
            _timer?.cancel();
          }
        });
      }
    });
  }

  Future<void> _handleOverride() async {
    // Show reason dialog for override
    final reason = await _showOverrideReasonDialog();
    if (reason != null && reason.isNotEmpty) {
      setState(() => _isOverriding = true);

      try {
        final userId = await UserManager.getCustomerId();
        if (userId == null) {
          Fluttertoast.showToast(msg: 'User not logged in');
          setState(() => _isOverriding = false);
          return;
        }

        // Call override API
        await _api.overrideTransaction(
          transactionId: widget.transaction.id,
          userId: userId,
          reason: reason,
        );

        // Update local transaction status
        final dbHelper = DatabaseHelper();
        final updatedTransaction = widget.transaction.copyWith(
          status: Transaction.STATUS_PENDING, // Allow proceeding
          fraudStatus: Transaction.FRAUD_REVIEW, // Downgrade to REVIEW
        );
        await dbHelper.updateTransaction(updatedTransaction);

        Fluttertoast.showToast(
          msg: '✅ Override successful! You can now proceed.',
          backgroundColor: Colors.green,
        );

        // Mark as overridden and proceed
        setState(() {
          _isOverridden = true;
          _isOverriding = false;
        });

        // Call the onOverride callback if provided
        if (widget.onOverride != null) {
          widget.onOverride!();
        }

        // Navigate to PIN screen after a brief delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            widget.onProceed();
          }
        });
      } catch (e) {
        Fluttertoast.showToast(
          msg: 'Override failed: $e',
          backgroundColor: Colors.red,
        );
        setState(() => _isOverriding = false);
      }
    }
  }

  Future<String?> _showOverrideReasonDialog() async {
    _reasonController.clear();
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'Override Blocked Transaction',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.8, // Wider dialog
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'This transaction was blocked by FraudGuard AI.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.orange,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Overriding a blocked transaction will mark it as reviewed. '
                            'This action is logged for security purposes.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please explain why this transaction is legitimate:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    decoration: InputDecoration(
                      hintText: 'Enter your reason...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    maxLines: 4,
                    autofocus: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel', style: TextStyle(fontSize: 14)),
              ),
              ElevatedButton(
                onPressed: () {
                  final reason = _reasonController.text.trim();
                  if (reason.isEmpty) {
                    Fluttertoast.showToast(msg: 'Please enter a reason');
                    return;
                  }
                  Navigator.pop(context, reason);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: const Text('Override & Proceed'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If override was successful, return a loading screen or pop
    if (_isOverridden) {
      return Scaffold(
        backgroundColor: Colors.green.shade700,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                'Override Successful!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Redirecting to payment...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      );
    }

    final isBlocked = widget.decision == Transaction.FRAUD_FRAUD;
    final isReview = widget.decision == Transaction.FRAUD_REVIEW;
    final riskPercent = (widget.riskScore * 100).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: isBlocked ? Colors.red.shade900 : Colors.orange.shade900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                if (_isOverriding)
                  const Column(
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Processing override...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  )
                else ...[
                  Icon(
                    isBlocked ? Icons.block : Icons.warning_amber,
                    size: 100,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isBlocked
                        ? 'Transaction Blocked'
                        : 'Suspicious Transaction',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Risk Score: $riskPercent%',
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Risk Factors:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...widget.reasons.map(
                          (reason) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.warning,
                                  color: Colors.orange,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reason['label'] ??
                                            reason['feature'] ??
                                            'Unknown Reason',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (reason['value'] != null)
                                        Text(
                                          'Value: ${reason['value']}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Transaction details section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transaction Details:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Amount',
                          '₹${widget.transaction.amount.toStringAsFixed(2)}',
                        ),
                        _buildDetailRow(
                          'Recipient',
                          widget.transaction.recipientContactId.toString(),
                        ),
                        if (widget.transaction.note != null &&
                            widget.transaction.note!.isNotEmpty)
                          _buildDetailRow('Note', widget.transaction.note!),
                        _buildDetailRow(
                          'Time',
                          _formatTime(widget.transaction.timestamp),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  if (isReview) ...[
                    Text(
                      _countdown > 0
                          ? 'You can proceed in $_countdown seconds'
                          : 'You can proceed now',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canProceed ? widget.onProceed : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Proceed Anyway',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ] else if (isBlocked) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleOverride,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'This is a legitimate payment',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.day}/${time.month}/${time.year} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
