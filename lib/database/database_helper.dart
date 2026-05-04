import 'package:fraudguard_pay/models/message_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:fraudguard_pay/models/transaction_model.dart' as tx;
import 'package:fraudguard_pay/models/contact_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'fg_pay.db');
    return await openDatabase(
      path,
      version: 2, // Incremented version for schema change
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Contacts table
    await db.execute('''
      CREATE TABLE contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        vpa TEXT NOT NULL UNIQUE,
        phone TEXT,
        avatar TEXT
      )
    ''');

    // Transactions table with contact IDs
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        sender_contact_id INTEGER NOT NULL,
        recipient_contact_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        note TEXT,
        is_fraud INTEGER DEFAULT 0,
        risk_factors TEXT,
        server_transaction_id TEXT,
        FOREIGN KEY (sender_contact_id) REFERENCES contacts (id) ON DELETE CASCADE,
        FOREIGN KEY (recipient_contact_id) REFERENCES contacts (id) ON DELETE CASCADE
      )
    ''');

    // Fraud flags table
    await db.execute('''
      CREATE TABLE fraud_flags (
        transaction_id TEXT PRIMARY KEY,
        risk_score REAL,
        risk_factors TEXT,
        flagged_at TEXT,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE
      )
    ''');

    // Messages table with contact IDs
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        sender_contact_id INTEGER NOT NULL,
        recipient_contact_id INTEGER NOT NULL,
        text TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        is_read INTEGER DEFAULT 0,
        FOREIGN KEY (sender_contact_id) REFERENCES contacts (id) ON DELETE CASCADE,
        FOREIGN KEY (recipient_contact_id) REFERENCES contacts (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Create new tables with contact IDs
      await db.execute('''
        CREATE TABLE transactions_new (
          id TEXT PRIMARY KEY,
          timestamp TEXT NOT NULL,
          sender_contact_id INTEGER NOT NULL,
          recipient_contact_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          status TEXT NOT NULL,
          note TEXT,
          is_fraud INTEGER DEFAULT 0,
          risk_factors TEXT,
          server_transaction_id TEXT,
          FOREIGN KEY (sender_contact_id) REFERENCES contacts (id) ON DELETE CASCADE,
          FOREIGN KEY (recipient_contact_id) REFERENCES contacts (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE messages_new (
          id TEXT PRIMARY KEY,
          sender_contact_id INTEGER NOT NULL,
          recipient_contact_id INTEGER NOT NULL,
          text TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          is_read INTEGER DEFAULT 0,
          FOREIGN KEY (sender_contact_id) REFERENCES contacts (id) ON DELETE CASCADE,
          FOREIGN KEY (recipient_contact_id) REFERENCES contacts (id) ON DELETE CASCADE
        )
      ''');

      // Migrate data from old tables if they exist
      final hasOldTransactions = await _tableExists(db, 'transactions');
      final hasOldMessages = await _tableExists(db, 'messages');
      final contacts = await db.query('contacts');

      if (hasOldTransactions && contacts.isNotEmpty) {
        final nameToId = {
          for (var c in contacts) c['name'] as String: c['id'] as int,
        };
        final oldTransactions = await db.query('transactions');

        for (var old in oldTransactions) {
          final senderName = old['sender_id'] as String;
          final recipientName = old['recipient'] as String;
          final senderId = nameToId[senderName];
          final recipientId = nameToId[recipientName];

          if (senderId != null && recipientId != null) {
            await db.insert('transactions_new', {
              'id': old['id'],
              'timestamp': old['timestamp'],
              'sender_contact_id': senderId,
              'recipient_contact_id': recipientId,
              'amount': old['amount'],
              'type': old['type'],
              'status': old['status'],
              'note': old['note'],
              'is_fraud': old['is_fraud'],
              'risk_factors': old['risk_factors'],
              'server_transaction_id': old['server_transaction_id'],
            });
          }
        }
      }

      if (hasOldMessages && contacts.isNotEmpty) {
        final nameToId = {
          for (var c in contacts) c['name'] as String: c['id'] as int,
        };
        final oldMessages = await db.query('messages');

        for (var old in oldMessages) {
          final senderName = old['sender_id'] as String;
          final recipientName = old['recipient_id'] as String;
          final senderId = nameToId[senderName];
          final recipientId = nameToId[recipientName];

          if (senderId != null && recipientId != null) {
            await db.insert('messages_new', {
              'id': old['id'],
              'sender_contact_id': senderId,
              'recipient_contact_id': recipientId,
              'text': old['text'],
              'timestamp': old['timestamp'],
              'is_read': old['is_read'],
            });
          }
        }
      }

      // Replace old tables
      if (hasOldTransactions) await db.execute('DROP TABLE transactions');
      if (hasOldMessages) await db.execute('DROP TABLE messages');
      await db.execute('ALTER TABLE transactions_new RENAME TO transactions');
      await db.execute('ALTER TABLE messages_new RENAME TO messages');
    }
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  }

  // ==================== CONTACTS ====================

  Future<int> insertContact(Contact contact) async {
    final db = await database;
    return await db.insert('contacts', contact.toMap());
  }

  Future<List<Contact>> getContacts() async {
    final db = await database;
    final maps = await db.query('contacts', orderBy: 'name ASC');
    return maps.map((map) => Contact.fromMap(map)).toList();
  }

  Future<Map<int, Contact>> getContactsMap() async {
    final contacts = await getContacts();
    return {for (var c in contacts) c.id!: c};
  }

  Future<Contact?> getContactById(int id) async {
    final db = await database;
    final maps = await db.query('contacts', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Contact.fromMap(maps.first);
    return null;
  }

  Future<int> updateContact(Contact contact) async {
    final db = await database;
    return await db.update(
      'contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  Future<int> deleteContact(int id) async {
    final db = await database;
    return await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== MESSAGES ====================

  Future<void> insertMessage(Message message) async {
    final db = await database;
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Message>> getMessagesBetween(
    int contactId1,
    int contactId2,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where:
          '(sender_contact_id = ? AND recipient_contact_id = ?) OR (sender_contact_id = ? AND recipient_contact_id = ?)',
      whereArgs: [contactId1, contactId2, contactId2, contactId1],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => Message.fromMap(map)).toList();
  }

  Future<int> deleteMessage(String messageId) async {
    final db = await database;
    return await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
  }

  // Get all messages
  Future<List<Message>> getAllMessages() async {
    final db = await database;
    final maps = await db.query('messages', orderBy: 'timestamp DESC');
    return maps.map((map) => Message.fromMap(map)).toList();
  }

  // Update a message
  Future<int> updateMessage(Message message) async {
    final db = await database;
    return await db.update(
      'messages',
      message.toMap(),
      where: 'id = ?',
      whereArgs: [message.id],
    );
  }

  // ==================== TRANSACTIONS ====================

  Future<void> insertTransaction(tx.Transaction txn) async {
    final db = await database;
    await db.insert(
      'transactions',
      txn.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<tx.Transaction>> getTransactions({bool onlyFraud = false}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: onlyFraud ? 'is_fraud = 1' : null,
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => tx.Transaction.fromMap(map)).toList();
  }

  Future<tx.Transaction?> getTransaction(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) return tx.Transaction.fromMap(result.first);
    return null;
  }

  Future<int> updateTransaction(tx.Transaction transaction) async {
    final db = await database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> updateFraudStatus(
    String transactionId,
    bool isFraud, {
    String? riskFactors,
  }) async {
    final db = await database;
    await db.update(
      'transactions',
      {'is_fraud': isFraud ? 1 : 0, 'risk_factors': riskFactors},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<int> deleteTransaction(String id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== FRAUD FLAGS ====================

  Future<void> insertFraudFlag(
    String transactionId,
    double riskScore,
    String riskFactorsJson, {
    String? flaggedAt,
  }) async {
    final db = await database;
    await db.insert('fraud_flags', {
      'transaction_id': transactionId,
      'risk_score': riskScore,
      'risk_factors': riskFactorsJson,
      'flagged_at': flaggedAt ?? DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await updateFraudStatus(transactionId, true, riskFactors: riskFactorsJson);
  }

  Future<Map<String, dynamic>?> getFraudFlag(String transactionId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'fraud_flags',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
    if (result.isNotEmpty) return result.first;
    return null;
  }

  Future<List<Map<String, dynamic>>>
  getAllTransactionsWithFraudDetails() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT t.*, f.risk_score, f.flagged_at
      FROM transactions t
      LEFT JOIN fraud_flags f ON t.id = f.transaction_id
      ORDER BY t.timestamp DESC
    ''');
  }
}
