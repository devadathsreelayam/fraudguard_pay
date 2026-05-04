// Chat-like interface showing transaction history with a specific contact.

// Flows: Contacts Screen → Payment Detail Screen → Payment Input Screen

import 'package:flutter/material.dart';
import 'package:fraudguard_pay/models/message_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:intl/intl.dart';
import 'package:fraudguard_pay/config/theme.dart';
import 'package:fraudguard_pay/screens/payment/payment_input_screen.dart';
import 'package:fraudguard_pay/database/database_helper.dart';

class PaymentDetailScreen extends StatefulWidget {
  final Contact contact;

  const PaymentDetailScreen({super.key, required this.contact});

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final int _myContactId = 0; // Fixed ID for "me"

  List<Message> _messages = [];
  List<Transaction> _transactions = [];
  // Map<int, Contact> _contactsMap = {};
  bool _isLoading = true;

  List<Transaction> get _relevantTransactions {
    return _transactions.where((txn) {
        bool sentByMe =
            (txn.senderContactId == _myContactId &&
                txn.recipientContactId == widget.contact.id);
        bool receivedByMe =
            (txn.senderContactId == widget.contact.id &&
                txn.recipientContactId == _myContactId);
        return sentByMe || receivedByMe;
      }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // final contactsMap = await _dbHelper.getContactsMap();
    final messages = await _dbHelper.getMessagesBetween(
      _myContactId,
      widget.contact.id!,
    );
    final allTransactions = await _dbHelper.getTransactions();

    setState(() {
      // _contactsMap = contactsMap;
      _messages = messages;
      _transactions = allTransactions;
      _isLoading = false;
    });
  }

  Future<void> _sendMessage() async {
    final String cleanText = _messageController.text.trim();
    if (cleanText.isEmpty) return;

    final newMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderContactId: _myContactId,
      recipientContactId: widget.contact.id!,
      text: cleanText,
      timestamp: DateTime.now(),
    );

    await _dbHelper.insertMessage(newMessage);

    setState(() {
      _messages.insert(0, newMessage);
      _messageController.clear();
    });
  }

  // String _getDisplayName(int contactId) {
  //   if (contactId == _myContactId) return "me";
  //   return _contactsMap[contactId]?.name ?? "Unknown";
  // }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txns = _relevantTransactions;
    final allItems = _buildCombinedList(txns);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: primaryDark,
      appBar: AppBar(
        backgroundColor: primaryDark,
        elevation: 0,
        title: Text(
          widget.contact.name,
          style: const TextStyle(color: textPrimary),
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: accentOrange),
              )
              : (allItems.isEmpty && _messages.isEmpty)
              ? _buildEmptyState()
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                reverse: true,
                itemCount: allItems.length,
                itemBuilder: (context, index) {
                  final item = allItems[index];
                  if (item['type'] == 'message') {
                    return _buildMessageBubble(item['message'] as Message);
                  } else {
                    return _buildTransactionCard(
                      item['transaction'] as Transaction,
                    );
                  }
                },
              ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  List<Map<String, dynamic>> _buildCombinedList(List<Transaction> txns) {
    List<Map<String, dynamic>> items = [];

    // Add messages
    for (var msg in _messages) {
      items.add({
        'type': 'message',
        'message': msg,
        'timestamp': msg.timestamp,
      });
    }

    // Add transactions
    for (var txn in txns) {
      items.add({
        'type': 'transaction',
        'transaction': txn,
        'timestamp': txn.timestamp,
      });
    }

    // Sort by timestamp (newest first for reverse list)
    items.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    return items;
  }

  Widget _buildMessageBubble(Message message) {
    bool isMe = message.senderContactId == _myContactId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? cardBg : secondaryDark,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('hh:mm a').format(message.timestamp),
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Transaction txn) {
    bool isMe = txn.senderContactId == _myContactId;
    bool isFailed = txn.status.toLowerCase() == "failed";
    bool isBlocked = txn.status.toLowerCase() == "blocked";
    bool isFlagged = txn.status.toLowerCase() == "flagged";
    bool isFraud = txn.isFraud;

    // Determine card styling
    Color cardBorderColor = borderColor;
    Color titleColor = Colors.white;
    String titleText = isMe ? "You paid" : "You received";
    IconData statusIcon = Icons.check_circle_rounded;

    if (isFraud) {
      cardBorderColor = Colors.red;
      titleColor = Colors.red;
      titleText =
          isMe ? "You paid (Fraud detected)" : "You received (Fraud detected)";
      statusIcon = Icons.warning_rounded;
    } else if (isFailed) {
      cardBorderColor = Colors.red;
      titleColor = Colors.red;
      titleText = isMe ? "Failed" : "You received (Failed)";
      statusIcon = Icons.cancel_rounded;
    } else if (isBlocked) {
      cardBorderColor = Colors.orange;
      titleColor = Colors.orange;
      titleText = isMe ? "Blocked" : "You received (Blocked)";
      statusIcon = Icons.block;
    } else if (isFlagged) {
      cardBorderColor = Colors.orange;
      titleColor = Colors.orange;
      titleText = isMe ? "Flagged" : "You received (Flagged)";
      statusIcon = Icons.flag_rounded;
    } else {
      // Success - green outline for sent, subtle for received
      if (isMe) {
        cardBorderColor = cardBg;
        titleColor = Colors.green;
        titleText = "You Paid";
      } else {
        cardBorderColor = borderColor; // No special border for received
        titleColor = textSecondary;
        titleText = "You Received";
        statusIcon = Icons.check_circle_rounded;
      }
    }

    // Different background for sent vs received
    Color cardBgColor = isMe ? cardBg : secondaryDark;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 200,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cardBorderColor,
            width:
                (isFraud ||
                        isFailed ||
                        isBlocked ||
                        isFlagged ||
                        (isMe && !isFraud && !isFailed))
                    ? 1.0
                    : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with status color
            Row(
              children: [
                Icon(statusIcon, color: titleColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  titleText,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Amount
            Text(
              "₹${txn.amount.toStringAsFixed(2)}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            // Note if exists
            if (txn.note != null && txn.note!.isNotEmpty) ...[
              Text(
                txn.note!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
            ],
            // Timestamp
            Text(
              DateFormat('dd MMM, hh:mm a').format(txn.timestamp),
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
            // Risk factors if fraud
            if (txn.isFraud && txn.riskFactors != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      color: Colors.red,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        txn.riskFactors!,
                        style: const TextStyle(color: Colors.red, fontSize: 9),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: secondaryDark,
            radius: 40,
            child: Text(
              widget.contact.name[0],
              style: const TextStyle(color: accentOrange, fontSize: 32),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.contact.name,
            style: const TextStyle(color: Colors.white, fontSize: 24),
          ),
          Text(
            "+91 ${widget.contact.phone}",
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          const Text(
            "No transactions yet",
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: primaryDark,
          border: Border(top: BorderSide(color: borderColor, width: 0.5)),
        ),
        child: Row(
          children: [
            // Message input with inline send
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: "Message...",
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.send,
                        color:
                            _messageController.text.trim().isEmpty
                                ? Colors.white38
                                : accentOrange,
                        size: 20,
                      ),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Pay button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            PaymentInputScreen(contact: widget.contact),
                  ),
                ).then((_) => _loadData());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                "Pay",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
