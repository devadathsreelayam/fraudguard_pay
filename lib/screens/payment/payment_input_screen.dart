// payment_input_screen.dart
/// Amount entry screen with contact avatar for payments.
/// Flows: Payment Detail Screen → Payment Input Screen → UPI PIN Screen
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:uuid/uuid.dart';
import 'package:fraudguard_pay/config/theme.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/services/api_service.dart';
import 'package:fraudguard_pay/services/user_manager.dart';
import 'package:fraudguard_pay/services/contact_resolution_service.dart';
import 'package:fraudguard_pay/utils/settings_manager.dart';
import 'upi_pin_screen.dart';
import 'fraud_warning_screen.dart';

class PaymentInputScreen extends StatefulWidget {
  final Contact contact;
  final String amount;

  const PaymentInputScreen({
    super.key,
    required this.contact,
    this.amount = "",
  });

  @override
  State<PaymentInputScreen> createState() => _PaymentInputScreenState();
}

class _PaymentInputScreenState extends State<PaymentInputScreen> {
  late TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ApiService _api = ApiService();
  final ContactResolutionService _resolutionService =
      ContactResolutionService();
  final Uuid _uuid = const Uuid();

  bool _isResolving = false;
  Contact? _resolvedContact;

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

  Future<void> _proceedToPay() async {
    final amountText = _amountController.text;
    if (amountText.isEmpty) return;

    final amount = double.tryParse(amountText) ?? 0.0;
    if (amount <= 0) {
      Fluttertoast.showToast(msg: 'Please enter a valid amount');
      return;
    }

    final note = _noteController.text.trim();

    // STEP 1: Resolve contact (if not already resolved with djangoId)
    if (widget.contact.djangoId == null) {
      await _resolveContact();
      if (_resolvedContact == null) return;
    } else {
      _resolvedContact = widget.contact;
    }

    // STEP 2: Show unverified merchant warning if needed
    if (!_resolvedContact!.isVerified && _resolvedContact!.isMerchant) {
      final shouldContinue = await _showUnverifiedMerchantWarning();
      if (!shouldContinue) return;
    }

    // STEP 3: Check if fraud detection is enabled
    final fraudCheckEnabled = await SettingsManager.isFraudCheckEnabled();

    if (fraudCheckEnabled) {
      await _performFraudCheck(amount, note);
    } else {
      _navigateToPinScreen(null, amountText, note);
    }
  }

  Future<void> _resolveContact() async {
    setState(() => _isResolving = true);

    try {
      final resolved = await _resolutionService.resolveContact(
        vpa: widget.contact.vpa,
        name: widget.contact.name,
        phone: widget.contact.phone,
      );

      setState(() => _resolvedContact = resolved);

      // Show verification badge toast
      if (!resolved.isVerified && resolved.isMerchant) {
        Fluttertoast.showToast(
          msg: '⚠️ ${resolved.name} is an unverified merchant',
          backgroundColor: Colors.orange,
        );
      } else if (resolved.isVerified) {
        Fluttertoast.showToast(
          msg: '✓ ${resolved.name} is verified',
          backgroundColor: Colors.green,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to verify recipient: $e');
      setState(() => _resolvedContact = null);
    } finally {
      setState(() => _isResolving = false);
    }
  }

  Future<bool> _showUnverifiedMerchantWarning() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Unverified Merchant'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_resolvedContact!.name} is not a verified merchant.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Transactions to unverified merchants may have higher risk '
                      'and could be flagged by FraudGuard.',
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
                              'You may need to provide additional verification '
                              'or the transaction might be blocked.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Continue Anyway'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<void> _performFraudCheck(double amount, String note) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final userId = await UserManager.getCustomerId();
      if (userId == null) {
        Navigator.pop(context);
        Fluttertoast.showToast(msg: 'User not logged in');
        return;
      }

      final deviceId = await UserManager.getDeviceId();
      final userLocation = 'Home';
      final networkType = '4G';

      // Use djangoId if available, otherwise use VPA
      final isMerchant = _resolvedContact!.isMerchant;
      final recipientIdentifier =
          _resolvedContact!.djangoId ?? _resolvedContact!.vpa;

      final result = await _api.predictTransaction(
        userId: userId,
        deviceId: deviceId,
        merchantVpa: isMerchant ? _resolvedContact!.vpa : null,
        recipientId: !isMerchant ? recipientIdentifier : null,
        amount: amount,
        timestamp: DateTime.now(),
        userLocation: userLocation,
        networkType: networkType,
        transactionType: isMerchant ? 'P2M' : 'P2P',
        note: note.isNotEmpty ? note : null,
      );

      Navigator.pop(context);

      print('=== PREDICTION RESPONSE ===');
      print('Success: ${result['success']}');
      print('Data: ${result['data']}');

      if (result['success'] != true) {
        Fluttertoast.showToast(msg: result['error'] ?? 'Fraud check failed');
        return;
      }

      final data = result['data'];
      final decision = data['decision'];
      final riskScore = (data['risk_score'] as num).toDouble();
      final reasons = data['reasons'] as List? ?? [];
      final serverTransactionId = data['transaction_id'];

      final recipientType =
          _resolvedContact!.isMerchant
              ? Transaction.RECIPIENT_TYPE_MERCHANT
              : Transaction.RECIPIENT_TYPE_CUSTOMER;

      final transaction = Transaction(
        id: serverTransactionId,
        timestamp: DateTime.now(),
        senderContactId: 0,
        recipientContactId: _resolvedContact!.localId ?? -1,
        amount: amount,
        transactionType:
            _resolvedContact!.isMerchant
                ? Transaction.TRANSACTION_TYPE_P2M
                : Transaction.TRANSACTION_TYPE_P2P,
        recipientType: recipientType,
        status: Transaction.STATUS_PENDING,
        fraudStatus: decision,
        note: note.isNotEmpty ? note : null,
        riskScore: riskScore,
        userLocation: userLocation,
        networkType: networkType,
        syncStatus: Transaction.SYNC_SYNCED,
      );

      await _dbHelper.insertTransaction(transaction);

      if (decision == Transaction.FRAUD_FRAUD) {
        final shouldOverride = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder:
                (_) => FraudWarningScreen(
                  transaction: transaction,
                  riskScore: riskScore,
                  reasons: reasons,
                  decision: decision,
                  onProceed: () => Navigator.pop(context, true),
                ),
          ),
        );

        if (shouldOverride == true) {
          final overrideReason = await _showOverrideReasonDialog();
          if (overrideReason != null && overrideReason.isNotEmpty) {
            try {
              await _api.overrideTransaction(
                transactionId: transaction.id,
                userId: userId,
                reason: overrideReason,
              );
              if (mounted) {
                _navigateToPinScreen(transaction, amount.toString(), note);
              }
            } catch (e) {
              Fluttertoast.showToast(msg: 'Override failed: $e');
            }
          }
        }
        return;
      } else if (decision == Transaction.FRAUD_REVIEW) {
        final shouldProceed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder:
                (_) => FraudWarningScreen(
                  transaction: transaction,
                  riskScore: riskScore,
                  reasons: reasons,
                  decision: decision,
                  onProceed: () => Navigator.pop(context, true),
                ),
          ),
        );

        if (shouldProceed != true) {
          await _dbHelper.deleteTransaction(transaction.id);
          return;
        }

        Fluttertoast.showToast(msg: '⚠️ Proceeding with flagged transaction');
        _navigateToPinScreen(transaction, amount.toString(), note);
      } else {
        Fluttertoast.showToast(msg: '✅ Low risk transaction, proceeding...');
        _navigateToPinScreen(transaction, amount.toString(), note);
      }
    } catch (e) {
      Navigator.pop(context);
      Fluttertoast.showToast(msg: 'Error: $e');
      print('Error in fraud check: $e');
    }
  }

  Future<String?> _showOverrideReasonDialog() async {
    final TextEditingController reasonController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Override Blocked Transaction'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('This transaction was blocked by FraudGuard.'),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for override',
                    hintText: 'Why is this transaction legitimate?',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed:
                    () => Navigator.pop(context, reasonController.text.trim()),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Proceed Anyway'),
              ),
            ],
          ),
    );
  }

  void _navigateToPinScreen(
    Transaction? transaction,
    String amount,
    String note,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => UpiPinScreen(
              contact: _resolvedContact!,
              amount: amount,
              note: note,
              transaction: transaction,
            ),
      ),
    );
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
            Stack(
              children: [
                CircleAvatar(
                  backgroundColor: secondaryDark,
                  radius: 40,
                  child: Text(
                    widget.contact.name[0].toUpperCase(),
                    style: const TextStyle(color: accentOrange, fontSize: 40),
                  ),
                ),
                if (_resolvedContact != null && _resolvedContact!.isVerified)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "Paying ${widget.contact.name}",
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            if (_resolvedContact != null &&
                _resolvedContact!.displayBadge.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _resolvedContact!.badgeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _resolvedContact!.displayBadge,
                    style: TextStyle(
                      color: _resolvedContact!.badgeColor,
                      fontSize: 11,
                    ),
                  ),
                ),
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
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
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
                    onPressed: _isResolving ? null : _proceedToPay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child:
                        _isResolving
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text(
                              "Proceed to Pay",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
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
