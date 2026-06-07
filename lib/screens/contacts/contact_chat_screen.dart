// contact_chat_screen.dart
/// Chat-like interface showing transaction history and messages with a specific contact.
/// Flows: Contacts Screen → Contact Chat Screen → Payment Input Screen

import 'package:flutter/material.dart';
import 'package:fraudguard_pay/models/message_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:intl/intl.dart';
import 'package:fraudguard_pay/config/theme.dart';
import 'package:fraudguard_pay/screens/payment/payment_input_screen.dart';
import 'package:fraudguard_pay/database/database_helper.dart';

class ContactChatScreen extends StatefulWidget {
  final Contact contact;

  const ContactChatScreen({super.key, required this.contact});

  @override
  State<ContactChatScreen> createState() => _ContactChatScreenState();
}

class _ContactChatScreenState extends State<ContactChatScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _messageController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final int _myContactId = 0; // Fixed ID for "me"

  List<Message> _messages = [];
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  /// Get all transactions between me and this contact (both sent AND received)
  List<Transaction> get _relevantTransactions {
    final contactLocalId = widget.contact.localId;
    if (contactLocalId == null) return [];

    final relevant =
        _transactions.where((txn) {
          // Transaction sent by me to this contact
          final bool sentByMe =
              txn.senderContactId == _myContactId &&
              txn.recipientContactId == contactLocalId;
          // Transaction received by me from this contact
          final bool receivedByMe =
              txn.senderContactId == contactLocalId &&
              txn.recipientContactId == _myContactId;
          return sentByMe || receivedByMe;
        }).toList();

    // Sort by timestamp (newest first)
    relevant.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return relevant;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when coming back to this screen (e.g., after payment)
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Get messages between me and this contact
      final messages = await _dbHelper.getMessagesBetween(
        _myContactId,
        widget.contact.localId!,
      );

      // Get all transactions from database
      final allTransactions = await _dbHelper.getTransactions();

      print(
        '📊 ContactChatScreen: Loaded ${allTransactions.length} total transactions',
      );
      print(
        '📊 Contact ID: ${widget.contact.localId}, Name: ${widget.contact.name}',
      );

      setState(() {
        _messages = messages;
        _transactions = allTransactions;
        _isLoading = false;
      });

      // Debug: Print relevant transactions
      final relevant = _relevantTransactions;
      print('📊 Relevant transactions for this chat: ${relevant.length}');
      for (var txn in relevant) {
        print(
          '   - ${txn.id}: ${txn.isSent ? "Sent" : "Received"} ₹${txn.amount}',
        );
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final String cleanText = _messageController.text.trim();
    if (cleanText.isEmpty) return;

    final newMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderContactId: _myContactId,
      recipientContactId: widget.contact.localId!,
      text: cleanText,
      timestamp: DateTime.now(),
    );

    await _dbHelper.insertMessage(newMessage);

    setState(() {
      _messages.insert(0, newMessage);
      _messageController.clear();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final txns = _relevantTransactions;
    final allItems = _buildCombinedList(txns);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: primaryDark,
      appBar: AppBar(
        backgroundColor: primaryDark,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: secondaryDark,
              child: Text(
                widget.contact.name.isNotEmpty
                    ? widget.contact.name[0].toUpperCase()
                    : "?",
                style: const TextStyle(color: accentOrange, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contact.name,
                  style: const TextStyle(color: textPrimary, fontSize: 16),
                ),
                if (widget.contact.isMerchant)
                  Text(
                    widget.contact.isVerified
                        ? "Verified Merchant"
                        : "Unverified Merchant",
                    style: TextStyle(
                      color:
                          widget.contact.isVerified
                              ? Colors.green
                              : Colors.orange,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: accentOrange,
        child:
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
          color: isMe ? accentOrange : secondaryDark,
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
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Transaction txn) {
    final bool isSent = txn.senderContactId == _myContactId;
    final bool isPending = txn.status == Transaction.STATUS_PENDING;
    final bool isSuccess = txn.status == Transaction.STATUS_SUCCESS;
    final bool isFailed = txn.status == Transaction.STATUS_FAILED;
    final bool isCancelled = txn.status == Transaction.STATUS_CANCELLED;
    final bool isFraud = txn.fraudStatus == Transaction.FRAUD_FRAUD;
    final bool isReview = txn.fraudStatus == Transaction.FRAUD_REVIEW;

    // Determine card styling
    Color cardBorderColor = borderColor;
    Color titleColor = Colors.white;
    String titleText = isSent ? "You paid" : "You received";
    IconData statusIcon = Icons.check_circle_rounded;

    if (isPending) {
      cardBorderColor = Colors.orange;
      titleColor = Colors.orange;
      titleText = isSent ? "Processing" : "Processing";
      statusIcon = Icons.pending;
    } else if (isFraud) {
      cardBorderColor = Colors.red;
      titleColor = Colors.red;
      titleText = isSent ? "Blocked (Fraud)" : "Suspicious";
      statusIcon = Icons.warning_rounded;
    } else if (isReview) {
      cardBorderColor = Colors.orange;
      titleColor = Colors.orange;
      titleText = isSent ? "Flagged for Review" : "Flagged";
      statusIcon = Icons.flag_rounded;
    } else if (isFailed) {
      cardBorderColor = Colors.red;
      titleColor = Colors.red;
      titleText = isSent ? "Failed" : "Failed";
      statusIcon = Icons.cancel_rounded;
    } else if (isCancelled) {
      cardBorderColor = Colors.grey;
      titleColor = Colors.grey;
      titleText = isSent ? "Cancelled" : "Cancelled";
      statusIcon = Icons.cancel_outlined;
    } else if (isSuccess) {
      if (isSent) {
        cardBorderColor = Colors.green;
        titleColor = Colors.green;
        titleText = "Success";
      } else {
        titleColor = Colors.green;
        titleText = "Received";
      }
      statusIcon = Icons.check_circle_rounded;
    }

    Color cardBgColor = isSent ? cardBg : secondaryDark;

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 240,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorderColor, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: titleColor, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    titleText,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "₹${txn.amount.toStringAsFixed(2)}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (txn.note != null && txn.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                txn.note!,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              DateFormat('dd MMM, hh:mm a').format(txn.timestamp),
              style: const TextStyle(color: Colors.white38, fontSize: 9),
            ),
            if (txn.riskScore != null && (isFraud || isReview)) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "Risk: ${(txn.riskScore! * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(color: Colors.red, fontSize: 9),
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
              widget.contact.name.isNotEmpty
                  ? widget.contact.name[0].toUpperCase()
                  : "?",
              style: const TextStyle(color: accentOrange, fontSize: 32),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.contact.name,
            style: const TextStyle(color: Colors.white, fontSize: 22),
          ),
          Text(
            widget.contact.vpa,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 20),
          const Text(
            "No transactions or messages yet",
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _navigateToPayment(),
            icon: const Icon(Icons.payment, size: 18),
            label: const Text("Send Money"),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentInputScreen(contact: widget.contact),
      ),
    ).then((_) => _loadData());
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
              onPressed: _navigateToPayment,
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
