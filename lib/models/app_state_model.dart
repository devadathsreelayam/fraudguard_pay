import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/models/message_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';

// ============================================================================
// GLOBAL APP STATE
// This centralizes app-wide state and loads seed data from SQLite.
// TODO: Replace with Provider/Riverpod state management for production.
// ============================================================================

final DatabaseHelper _dbHelper = DatabaseHelper();

List<Transaction> transactionHistory = [];
List<Transaction> fraudHistory = [];
List<Contact> contacts = [];
List<Message> messages = [];

final List<Contact> _defaultContacts = [
  Contact(
    id: 1,
    name: "Devadath R",
    vpa: "devadath@oksbi",
    phone: "9876543210",
  ),
  Contact(
    id: 2,
    name: "Sasikumar",
    vpa: "sasikumar@oksbi",
    phone: "9876543211",
  ),
  Contact(id: 3, name: "Nandana", vpa: "nandana@oksbi", phone: "9876543212"),
  Contact(id: 4, name: "Aarav Sharma", vpa: "aarav@oksbi", phone: "9876543213"),
  Contact(id: 5, name: "Kiran Rao", vpa: "kiran@oksbi", phone: "9876543214"),
];

final List<Transaction> _defaultTransactionHistory = [
  Transaction(
    id: "1",
    timestamp: DateTime.parse("2026-04-20 14:20:00"),
    senderContactId: 0,
    recipientContactId: 1,
    amount: 1500,
  ),
  Transaction(
    id: "2",
    timestamp: DateTime.parse("2026-04-20 16:20:00"),
    senderContactId: 0,
    recipientContactId: 2,
    amount: 248,
  ),
  Transaction(
    id: "3",
    timestamp: DateTime.parse("2026-04-22 16:20:00"),
    senderContactId: 3,
    recipientContactId: 0,
    amount: 18,
    type: "Money Received",
    note: "For tea",
  ),
  Transaction(
    id: "4",
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    senderContactId: 4,
    recipientContactId: 0,
    amount: 500,
    type: "Money Received",
    note: "Lunch repayment",
  ),
  Transaction(
    id: "5",
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
    senderContactId: 5,
    recipientContactId: 0,
    amount: 1200,
    type: "Money Received",
    note: "Refund",
  ),
  Transaction(
    id: "6",
    timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    senderContactId: 0,
    recipientContactId: 1,
    amount: 854,
    note: "Refund",
    status: 'Failed',
  ),
];

final List<Transaction> _defaultFraudHistory = [
  Transaction(
    id: "7",
    senderContactId: 0,
    type: "Money Sent",
    timestamp: DateTime.parse("2026-04-20 14:20"),
    recipientContactId: 7,
    amount: 5000.0,
    status: "Blocked",
    isFraud: true,
    riskFactors:
        "High velocity: Multiple attempts in 5 minutes. This pattern is consistent with brute-force testing of stolen credentials.",
  ),
  Transaction(
    id: "8",
    senderContactId: 0,
    type: "Money Sent",
    timestamp: DateTime.parse("2026-04-18 09:15"),
    recipientContactId: 8,
    amount: 12500.0,
    status: "Flagged",
    isFraud: true,
    riskFactors:
        "New device login from an unauthorized location combined with a high-value transfer request.",
  ),
  Transaction(
    id: "9",
    senderContactId: 0,
    type: "Money Sent",
    timestamp: DateTime.parse("2026-04-15 18:45"),
    recipientContactId: 8,
    amount: 200.0,
    status: "Flagged",
    isFraud: true,
    riskFactors:
        "Recipient VPA matches a known database of phishing accounts reported by other financial institutions.",
  ),
  Transaction(
    id: "10",
    senderContactId: 0,
    type: "Money Sent",
    timestamp: DateTime.parse("2026-04-15 18:45"),
    recipientContactId: 8,
    amount: 200.0,
    status: "Flagged",
    isFraud: true,
    riskFactors:
        "Recipient VPA matches a known database of phishing accounts reported by other financial institutions.",
  ),
];

Future<void> initializeGlobalData() async {
  final storedTransactions = await _dbHelper.getTransactions();

  if (storedTransactions.isNotEmpty) {
    transactionHistory = storedTransactions;
    fraudHistory = await _dbHelper.getTransactions(onlyFraud: true);
  } else {
    transactionHistory = List<Transaction>.from(_defaultTransactionHistory);
    fraudHistory = List<Transaction>.from(_defaultFraudHistory);
  }

  final storedContacts = await _dbHelper.getContacts();
  contacts =
      storedContacts.isNotEmpty
          ? storedContacts // ← Already List<Contact>, no conversion needed
          : List<Contact>.from(_defaultContacts);
}

// Future<void> loadMessages(Contact contact) async {
//   final dbHelper = DatabaseHelper();
//   messages = await dbHelper.getMessagesBetween(0, contact);
// }

// Future<void> sendAndSaveMessage(String recipientId, String text) async {
//   final dbHelper = DatabaseHelper();
//   final newMessage = Message(
//     id: DateTime.now().millisecondsSinceEpoch.toString(),
//     senderContactId: 0,
//     recipientContactId: recipientId,
//     text: text,
//     timestamp: DateTime.now(),
//   );
//   await dbHelper.insertMessage(newMessage);
//   messages.insert(0, newMessage);
// }
