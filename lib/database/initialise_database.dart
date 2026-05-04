import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';

Future<void> initDatabaseData() async {
  print("🔵 initDatabaseData: Started");

  final dbHelper = DatabaseHelper();

  final existingTransactions = await dbHelper.getTransactions();
  final existingContacts = await dbHelper.getContacts();

  print("🔵 Existing transactions: ${existingTransactions.length}");
  print("🔵 Existing contacts: ${existingContacts.length}");

  if (existingTransactions.isNotEmpty && existingContacts.isNotEmpty) {
    print("🟢 Database already has data. Skipping initialisation.");
    return;
  }

  print("🟡 Inserting initial data...");

  if (existingContacts.isEmpty) {
    final contacts = [
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
      Contact(
        id: 3,
        name: "Nandana",
        vpa: "nandana@oksbi",
        phone: "9876543212",
      ),
      Contact(
        id: 4,
        name: "Arun Krishna",
        vpa: "arunks@oksbi",
        phone: "9876543213",
      ),
      Contact(id: 5, name: "Kiran R", vpa: "kiran@oksbi", phone: "9876543214"),
      Contact(id: 6, name: "Husna", vpa: "husna@okaxis", phone: "9976543214"),

      // Fraud Accounts
      Contact(
        id: 7,
        name: "Dekrot",
        vpa: "dekrot@fraudpay",
        phone: "9176543214",
      ),
      Contact(
        id: 8,
        name: "MockMan",
        vpa: "mockman@okaxis",
        phone: "1145689723",
      ),
      Contact(
        id: 9,
        name: "Sher Singh",
        vpa: "shersher112@myupi",
        phone: "2456543214",
      ),
    ];

    for (var contact in contacts) {
      try {
        await dbHelper.insertContact(contact);
        print("✅ Inserted contact: ${contact.name}");
      } catch (e) {
        print("❌ Error inserting contact ${contact.name}: $e");
      }
    }
  }

  if (existingTransactions.isEmpty) {
    final transactions = [
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
      Transaction(
        id: "7",
        timestamp: DateTime.parse("2026-04-20 14:20:00"),
        senderContactId: 0,
        recipientContactId: 7,
        amount: 5000,
        type: "Money Sent",
        status: "Blocked",
        isFraud: true,
      ),
      Transaction(
        id: "8",
        timestamp: DateTime.parse("2026-04-18 09:15:00"),
        senderContactId: 0,
        recipientContactId: 8,
        amount: 12500,
        type: "Money Sent",
        status: "Flagged",
        isFraud: true,
      ),
      Transaction(
        id: "9",
        timestamp: DateTime.parse("2026-04-15 18:45:00"),
        senderContactId: 0,
        recipientContactId: 9,
        amount: 200,
        type: "Money Sent",
        status: "Flagged",
        isFraud: true,
      ),
      Transaction(
        id: "10",
        timestamp: DateTime.parse("2026-04-15 18:45:00"),
        senderContactId: 0,
        recipientContactId: 9,
        amount: 200,
        type: "Money Sent",
        status: "Flagged",
        isFraud: true,
      ),
    ];

    for (var tx in transactions) {
      try {
        await dbHelper.insertTransaction(tx);
        print("✅ Inserted transaction: ${tx.id}");
      } catch (e) {
        print("❌ Error inserting ${tx.id}: $e");
      }
    }

    final fraudFlags = [
      {
        'transaction_id': "7",
        'risk_score': 0.95,
        'risk_factors':
            "High velocity: Multiple attempts in 5 minutes. This pattern is consistent with brute-force testing of stolen credentials.",
        'flagged_at': DateTime.parse("2026-04-20 14:25:00").toIso8601String(),
      },
      {
        'transaction_id': "8",
        'risk_score': 0.88,
        'risk_factors':
            "New device login from an unauthorized location combined with a high-value transfer request.",
        'flagged_at': DateTime.parse("2026-04-18 09:20:00").toIso8601String(),
      },
      {
        'transaction_id': "9",
        'risk_score': 0.72,
        'risk_factors':
            "Recipient VPA matches a known database of phishing accounts reported by other financial institutions.",
        'flagged_at': DateTime.parse("2026-04-15 18:50:00").toIso8601String(),
      },
      {
        'transaction_id': "10",
        'risk_score': 0.72,
        'risk_factors':
            "Recipient VPA matches a known database of phishing accounts reported by other financial institutions.",
        'flagged_at': DateTime.parse("2026-04-15 18:50:00").toIso8601String(),
      },
    ];

    for (var flag in fraudFlags) {
      try {
        await dbHelper.insertFraudFlag(
          flag['transaction_id'] as String,
          flag['risk_score'] as double,
          flag['risk_factors'] as String,
          flaggedAt: flag['flagged_at'] as String?,
        );
        print("✅ Inserted fraud flag for: ${flag['transaction_id']}");
      } catch (e) {
        print("❌ Error inserting fraud flag: $e");
      }
    }
  }

  final finalCount = await dbHelper.getTransactions();
  print("🟢 Final transaction count: ${finalCount.length}");
  print("✅ Initial data insertion complete.");
}
