import 'package:flutter/material.dart';
import 'package:fraudguard_pay/config/theme.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/models/message_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';

/// Debug Database Admin Screen
/// Access via: DebugDatabaseScreen() or through a hidden route
/// Allows full CRUD operations directly from the app
class DebugDatabaseScreen extends StatefulWidget {
  const DebugDatabaseScreen({super.key});

  @override
  State<DebugDatabaseScreen> createState() => _DebugDatabaseScreenState();
}

class _DebugDatabaseScreenState extends State<DebugDatabaseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Contact> _allContacts = [];
  List<Transaction> _allTransactions = [];
  List<Message> _allMessages = [];
  Map<int, Contact> _contactsMap = {};

  // Contact form controllers
  final contactNameController = TextEditingController();
  final contactVpaController = TextEditingController();
  final contactPhoneController = TextEditingController();
  int? _editingContactId;

  // Transaction form controllers
  final txnIdController = TextEditingController();
  final txnRecipientController = TextEditingController();
  final txnAmountController = TextEditingController();
  final txnSenderController = TextEditingController();
  final txnTypeController = TextEditingController();
  final txnStatusController = TextEditingController();
  final txnNoteController = TextEditingController();
  String? _editingTransactionId;

  // Message form controllers
  final messageIdController = TextEditingController();
  final messageSenderController = TextEditingController();
  final messageRecipientController = TextEditingController();
  final messageTextController = TextEditingController();
  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  bool _isLoading = true;

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final contacts = await _dbHelper.getContacts();
    final transactions = await _dbHelper.getTransactions();
    final messages = await _dbHelper.getAllMessages();

    setState(() {
      _allContacts = contacts;
      _allTransactions = transactions;
      _allMessages = messages;
      _contactsMap = {for (var c in contacts) c.id!: c};
      _isLoading = false;
    });
  }

  String _getContactName(int? contactId) {
    if (contactId == null) return "Unknown";
    return _contactsMap[contactId]?.name ?? "Unknown";
  }

  // ==================== CONTACT OPERATIONS ====================

  void _showContactForm({Contact? contact}) {
    if (contact != null) {
      _editingContactId = contact.id;
      contactNameController.text = contact.name;
      contactVpaController.text = contact.vpa;
      contactPhoneController.text = contact.phone;
    } else {
      _editingContactId = null;
      contactNameController.clear();
      contactVpaController.clear();
      contactPhoneController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _editingContactId == null ? 'Add Contact' : 'Edit Contact',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contactNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: textSecondary),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactVpaController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'VPA',
                    labelStyle: TextStyle(color: textSecondary),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactPhoneController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    labelStyle: TextStyle(color: textSecondary),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _editingContactId == null
                                  ? accentOrange
                                  : Colors.orange,
                        ),
                        onPressed: _saveContact,
                        child: Text(
                          _editingContactId == null ? 'Add' : 'Update',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    if (_editingContactId != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteContact(
                              _editingContactId!,
                              contactNameController.text,
                            );
                          },
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  void _saveContact() async {
    if (contactNameController.text.isEmpty ||
        contactVpaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Name and VPA are required')),
      );
      return;
    }

    final contact = Contact(
      id: null,
      name: contactNameController.text,
      vpa: contactVpaController.text,
      phone:
          contactPhoneController.text.isNotEmpty
              ? contactPhoneController.text
              : "",
    );

    if (_editingContactId == null) {
      await _dbHelper.insertContact(contact);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Contact added')));
    } else {
      await _dbHelper.updateContact(contact);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Contact updated')));
    }

    Navigator.pop(context);
    _loadData();
  }

  void _deleteContact(int id, String name) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Contact?'),
            content: Text('Remove $name?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  _dbHelper.deleteContact(id).then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Contact deleted')),
                    );
                    _loadData();
                    Navigator.pop(context);
                  });
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  // ==================== TRANSACTION OPERATIONS ====================

  void _showTransactionForm({Transaction? transaction}) {
    if (transaction != null) {
      _editingTransactionId = transaction.id;
      txnIdController.text = transaction.id;
      txnSenderController.text = transaction.senderContactId.toString();
      txnRecipientController.text = transaction.recipientContactId.toString();
      txnAmountController.text = transaction.amount.toString();
      txnTypeController.text = transaction.type;
      txnStatusController.text = transaction.status;
      txnNoteController.text = transaction.note ?? '';
    } else {
      _editingTransactionId = null;
      txnIdController.clear();
      txnSenderController.text = '0';
      txnRecipientController.clear();
      txnAmountController.clear();
      txnTypeController.text = 'Money Sent';
      txnStatusController.text = 'Success';
      txnNoteController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _editingTransactionId == null
                        ? 'Add Transaction'
                        : 'Edit Transaction',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: txnIdController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Transaction ID',
                      labelStyle: TextStyle(color: textSecondary),
                      border: OutlineInputBorder(),
                      hintText: 'e.g., TXN_001',
                    ),
                    readOnly: _editingTransactionId != null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: txnSenderController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sender Contact ID',
                      labelStyle: TextStyle(color: textSecondary),
                      border: OutlineInputBorder(),
                      hintText: 'Contact ID (0 = me)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: txnRecipientController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Recipient Contact ID',
                      labelStyle: TextStyle(color: textSecondary),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: txnAmountController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      labelStyle: TextStyle(color: textSecondary),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: txnTypeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Type (Money Sent / Money Received)',
                      labelStyle: TextStyle(color: textSecondary),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: txnStatusController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Status (Success / Failed / Pending)',
                      labelStyle: TextStyle(color: textSecondary),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: txnNoteController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Note (Optional)',
                      labelStyle: TextStyle(color: textSecondary),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _editingTransactionId == null
                                    ? accentOrange
                                    : Colors.orange,
                          ),
                          onPressed: _saveTransaction,
                          child: Text(
                            _editingTransactionId == null ? 'Add' : 'Update',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      if (_editingTransactionId != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteTransaction(_editingTransactionId!);
                            },
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
    );
  }

  void _saveTransaction() async {
    if (txnIdController.text.isEmpty ||
        txnRecipientController.text.isEmpty ||
        txnAmountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Required fields: ID, Recipient ID, Amount'),
        ),
      );
      return;
    }

    final amount = double.tryParse(txnAmountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Amount must be greater than 0')),
      );
      return;
    }

    final senderId = int.tryParse(txnSenderController.text) ?? 0;
    final recipientId = int.tryParse(txnRecipientController.text) ?? -1;

    if (recipientId == -1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('❌ Invalid recipient ID')));
      return;
    }

    final transaction = Transaction(
      id: txnIdController.text,
      timestamp: DateTime.now(),
      senderContactId: senderId,
      recipientContactId: recipientId,
      amount: amount,
      type:
          txnTypeController.text.isNotEmpty
              ? txnTypeController.text
              : 'Money Sent',
      status:
          txnStatusController.text.isNotEmpty
              ? txnStatusController.text
              : 'Success',
      note: txnNoteController.text.isNotEmpty ? txnNoteController.text : null,
    );

    if (_editingTransactionId == null) {
      await _dbHelper.insertTransaction(transaction);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Transaction added')));
    } else {
      await _dbHelper.updateTransaction(transaction);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Transaction updated')));
    }

    Navigator.pop(context);
    _loadData();
  }

  void _deleteTransaction(String id) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Transaction?'),
            content: Text('Remove transaction $id?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  _dbHelper.deleteTransaction(id).then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Transaction deleted')),
                    );
                    _loadData();
                    Navigator.pop(context);
                  });
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _toggleFraudStatus(Transaction txn) async {
    final newFraudStatus = !txn.isFraud;
    final riskFactors =
        newFraudStatus
            ? 'Marked as fraud from debug screen on ${DateTime.now()}'
            : null;

    await _dbHelper.updateFraudStatus(
      txn.id,
      newFraudStatus,
      riskFactors: riskFactors,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newFraudStatus ? '🚨 Marked as fraudulent' : '✅ Removed fraud flag',
        ),
      ),
    );
    _loadData();
  }

  // ==================== MESSAGE OPERATIONS ====================

  void _showMessageForm({Message? message}) {
    if (message != null) {
      _editingMessageId = message.id;
      messageIdController.text = message.id;
      messageSenderController.text = message.senderContactId.toString();
      messageRecipientController.text = message.recipientContactId.toString();
      messageTextController.text = message.text;
    } else {
      _editingMessageId = null;
      messageIdController.clear();
      messageSenderController.text = '0';
      messageRecipientController.clear();
      messageTextController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _editingMessageId == null ? 'Add Message' : 'Edit Message',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageIdController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Message ID',
                    labelStyle: TextStyle(color: textSecondary),
                    border: OutlineInputBorder(),
                    hintText: 'e.g., msg_001',
                  ),
                  readOnly: _editingMessageId != null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageSenderController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sender Contact ID',
                    labelStyle: TextStyle(color: textSecondary),
                    border: OutlineInputBorder(),
                    hintText: 'Contact ID (0 = me)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageRecipientController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Recipient Contact ID',
                    labelStyle: TextStyle(color: textSecondary),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageTextController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Message Text',
                    labelStyle: TextStyle(color: textSecondary),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _editingMessageId == null
                                  ? accentOrange
                                  : Colors.orange,
                        ),
                        onPressed: _saveMessage,
                        child: Text(
                          _editingMessageId == null ? 'Add' : 'Update',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    if (_editingMessageId != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteMessage(_editingMessageId!);
                          },
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  void _saveMessage() async {
    if (messageIdController.text.isEmpty ||
        messageRecipientController.text.isEmpty ||
        messageTextController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Required fields: ID, Recipient ID, Text'),
        ),
      );
      return;
    }

    final senderId = int.tryParse(messageSenderController.text) ?? 0;
    final recipientId = int.tryParse(messageRecipientController.text) ?? -1;

    if (recipientId == -1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('❌ Invalid recipient ID')));
      return;
    }

    final message = Message(
      id: messageIdController.text,
      senderContactId: senderId,
      recipientContactId: recipientId,
      text: messageTextController.text,
      timestamp: DateTime.now(),
    );

    if (_editingMessageId == null) {
      await _dbHelper.insertMessage(message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Message added')));
    } else {
      await _dbHelper.updateMessage(message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Message updated')));
    }

    Navigator.pop(context);
    _loadData();
  }

  void _deleteMessage(String id) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Message?'),
            content: Text('Remove message $id?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  _dbHelper.deleteMessage(id).then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Message deleted')),
                    );
                    _loadData();
                    Navigator.pop(context);
                  });
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        backgroundColor: primaryDark,
        title: const Text('🔧 Debug Database'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Contacts'),
            Tab(text: 'Transactions'),
            Tab(text: 'Messages'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: accentOrange),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildContactsTab(),
                  _buildTransactionsTab(),
                  _buildMessagesTab(),
                ],
              ),
    );
  }

  Widget _buildContactsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: accentOrange),
              onPressed: () => _showContactForm(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add New Contact',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('📋 All Contacts (${_allContacts.length})'),
          _buildContactsList(),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    if (_allContacts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No contacts yet',
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _allContacts.length,
      itemBuilder: (context, index) {
        final contact = _allContacts[index];
        return Card(
          color: cardBg,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              contact.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${contact.vpa} • ${contact.phone}',
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: () => _showContactForm(contact: contact),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteContact(contact.id!, contact.name),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: accentOrange),
              onPressed: () => _showTransactionForm(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add New Transaction',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            '📋 All Transactions (${_allTransactions.length})',
          ),
          _buildTransactionsList(),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_allTransactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No transactions yet',
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _allTransactions.length,
      itemBuilder: (context, index) {
        final txn = _allTransactions[index];
        return Card(
          color: txn.isFraud ? const Color(0xFF8B0000) : cardBg,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              '${_getContactName(txn.senderContactId)} → ${_getContactName(txn.recipientContactId)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '₹${txn.amount.toStringAsFixed(2)} • ${txn.status} • ID: ${txn.id}',
              style: TextStyle(
                color: txn.isFraud ? Colors.red : textSecondary,
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    txn.isFraud ? Icons.warning_rounded : Icons.shield_outlined,
                  ),
                  color: txn.isFraud ? Colors.red : Colors.green,
                  onPressed: () => _toggleFraudStatus(txn),
                  tooltip: txn.isFraud ? 'Remove fraud flag' : 'Mark as fraud',
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: () => _showTransactionForm(transaction: txn),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteTransaction(txn.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessagesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: accentOrange),
              onPressed: () => _showMessageForm(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add New Message',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('📋 All Messages (${_allMessages.length})'),
          _buildMessagesList(),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_allMessages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No messages yet',
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _allMessages.length,
      itemBuilder: (context, index) {
        final msg = _allMessages[index];
        return Card(
          color: cardBg,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              '${_getContactName(msg.senderContactId)} → ${_getContactName(msg.recipientContactId)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${msg.text} • ${msg.timestamp.toString().substring(0, 16)}',
              style: const TextStyle(color: textSecondary, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: () => _showMessageForm(message: msg),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteMessage(msg.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: accentOrange,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    contactNameController.dispose();
    contactVpaController.dispose();
    contactPhoneController.dispose();
    txnIdController.dispose();
    txnRecipientController.dispose();
    txnAmountController.dispose();
    txnSenderController.dispose();
    txnTypeController.dispose();
    txnStatusController.dispose();
    txnNoteController.dispose();
    messageIdController.dispose();
    messageSenderController.dispose();
    messageRecipientController.dispose();
    messageTextController.dispose();
    super.dispose();
  }
}
