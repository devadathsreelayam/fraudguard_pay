// upi_pin_screen.dart

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:fraudguard_pay/services/api_service.dart';
import 'package:fraudguard_pay/services/user_manager.dart';
import 'payment_success_screen.dart';

class UpiPinScreen extends StatefulWidget {
  final Contact contact;
  final String amount;
  final String note;
  final bool isCheckingBalance;
  final Transaction? transaction;

  const UpiPinScreen({
    super.key,
    required this.contact,
    required this.amount,
    required this.note,
    this.isCheckingBalance = false,
    this.transaction,
  });

  @override
  State<UpiPinScreen> createState() => _UpiPinScreenState();
}

class _UpiPinScreenState extends State<UpiPinScreen> {
  String _pin = "";
  int _attempts = 0;
  final int _maxAttempts = 3;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ApiService _api = ApiService();
  bool _isProcessing = false;

  void _onKeyTap(String value) {
    if (_pin.length < 4 && !_isProcessing) {
      setState(() {
        _pin += value;
      });
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty && !_isProcessing) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _onOk() {
    if (_pin.length == 4 && !_isProcessing) {
      _handleVerification();
    } else if (_pin.length != 4) {
      Fluttertoast.showToast(msg: "Please enter a 4-digit PIN");
    }
  }

  Future<void> _handleVerification() async {
    if (_pin == "1234") {
      setState(() => _isProcessing = true);

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      if (widget.isCheckingBalance) {
        _showBalanceWindow();
      } else {
        await _handleSuccessfulPayment();
      }

      setState(() => _isProcessing = false);
    } else {
      _attempts++;
      int remaining = _maxAttempts - _attempts;

      if (_attempts >= _maxAttempts) {
        await _handleFinalFailure();
      } else {
        setState(() => _pin = "");
        Fluttertoast.showToast(
          msg: "Incorrect PIN. $remaining attempts left.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _handleSuccessfulPayment() async {
    try {
      final userId = await UserManager.getCustomerId();

      if (widget.transaction != null) {
        await _api.updateTransactionStatus(
          transactionId: widget.transaction!.id,
          status: Transaction.STATUS_SUCCESS,
          userId: userId ?? '',
        );

        final updatedTransaction = widget.transaction!.copyWith(
          status: Transaction.STATUS_SUCCESS,
          syncStatus: Transaction.SYNC_SYNCED,
        );

        await _dbHelper.updateTransaction(updatedTransaction);

        await _navigateToSuccess(updatedTransaction);
      } else {
        await _navigateToLegacySuccess();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error updating transaction: $e');
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleFinalFailure() async {
    setState(() => _isProcessing = true);

    try {
      if (widget.transaction != null && !widget.isCheckingBalance) {
        final userId = await UserManager.getCustomerId();

        await _api.updateTransactionStatus(
          transactionId: widget.transaction!.id,
          status: Transaction.STATUS_FAILED,
          userId: userId ?? '',
        );

        final updatedTransaction = widget.transaction!.copyWith(
          status: Transaction.STATUS_FAILED,
          syncStatus: Transaction.SYNC_SYNCED,
        );

        await _dbHelper.updateTransaction(updatedTransaction);
      }

      Fluttertoast.showToast(
        msg: "Too many failed attempts. Transaction failed.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _navigateToSuccess(Transaction transaction) async {
    // Ensure contact has a local_id before proceeding
    Contact contactToUse = widget.contact;

    if (contactToUse.localId == null) {
      final newLocalId = await _dbHelper.insertContact(contactToUse);
      contactToUse = Contact(
        localId: newLocalId,
        name: contactToUse.name,
        vpa: contactToUse.vpa,
        phone: contactToUse.phone,
        isVerified: contactToUse.isVerified,
        isMerchant: contactToUse.isMerchant,
        djangoId: contactToUse.djangoId,
        lastPaidAt: contactToUse.lastPaidAt,
      );
    }

    // Update last_paid_at for this contact
    await _dbHelper.updateContactLastPaid(contactToUse.vpa);

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder:
            (_) => PaymentSuccessScreen(
              contact: contactToUse,
              amount: widget.amount,
              note: widget.note,
              transaction: transaction,
            ),
      ),
      (route) => route.isFirst,
    );
  }

  Future<void> _navigateToLegacySuccess() async {
    Contact contactToUse = widget.contact;

    if (contactToUse.localId == null) {
      final newLocalId = await _dbHelper.insertContact(contactToUse);
      contactToUse = Contact(
        localId: newLocalId,
        name: contactToUse.name,
        vpa: contactToUse.vpa,
        phone: contactToUse.phone,
        isVerified: contactToUse.isVerified,
        isMerchant: contactToUse.isMerchant,
        djangoId: contactToUse.djangoId,
        lastPaidAt: contactToUse.lastPaidAt,
      );
    }

    // Update last_paid_at for this contact
    await _dbHelper.updateContactLastPaid(contactToUse.vpa);

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder:
            (_) => PaymentSuccessScreen(
              contact: contactToUse,
              amount: widget.amount,
              note: widget.note,
              transaction: null,
            ),
      ),
      (route) => route.isFirst,
    );
  }

  void _showBalanceWindow() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1E3A6F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
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
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ).then((_) {
      setState(() => _isProcessing = false);
    });
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
        leading:
            _isProcessing
                ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
      ),
      body: Column(
        children: [
          _buildTopBar(),
          const Spacer(),
          const Text(
            "ENTER 4-DIGIT PIN",
            style: TextStyle(letterSpacing: 2, color: Colors.blueGrey),
          ),
          const SizedBox(height: 20),
          _buildPinDots(),
          const Spacer(),
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
                  if (!_isProcessing) {
                    if (key == 'backspace') {
                      _onBackspace();
                    } else if (key == 'ok') {
                      _onOk();
                    } else if (key != null) {
                      _onKeyTap(key);
                    }
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
