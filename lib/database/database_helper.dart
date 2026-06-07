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
      version: 4, // Incremented version for new schema
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Contacts table with new schema
    await db.execute('''
      CREATE TABLE contacts (
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        vpa TEXT NOT NULL UNIQUE,
        phone TEXT,
        avatar TEXT,
        is_verified INTEGER DEFAULT 0,
        is_merchant INTEGER DEFAULT 1,
        django_id TEXT,
        last_paid_at TEXT
      )
    ''');

    // Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        sender_contact_id INTEGER NOT NULL,
        recipient_contact_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        transaction_type TEXT NOT NULL,
        recipient_type TEXT NOT NULL,
        status TEXT NOT NULL,
        fraud_status TEXT NOT NULL,
        note TEXT,
        risk_score REAL,
        user_location TEXT,
        network_type TEXT,
        sync_status TEXT DEFAULT 'pending'
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

    // Messages table
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        sender_contact_id INTEGER NOT NULL,
        recipient_contact_id INTEGER NOT NULL,
        text TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        is_read INTEGER DEFAULT 0,
        FOREIGN KEY (sender_contact_id) REFERENCES contacts (local_id) ON DELETE CASCADE,
        FOREIGN KEY (recipient_contact_id) REFERENCES contacts (local_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      // Drop and recreate contacts table with new schema
      try {
        await db.execute('DROP TABLE IF EXISTS contacts');
        await db.execute('''
          CREATE TABLE contacts (
            local_id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            vpa TEXT NOT NULL UNIQUE,
            phone TEXT,
            avatar TEXT,
            is_verified INTEGER DEFAULT 0,
            is_merchant INTEGER DEFAULT 1,
            django_id TEXT,
            last_paid_at TEXT
          )
        ''');
      } catch (e) {}

      // Add missing columns to transactions table
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN transaction_type TEXT DEFAULT "P2M"',
        );
      } catch (e) {}
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN recipient_type TEXT DEFAULT "MERCHANT"',
        );
      } catch (e) {}
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN fraud_status TEXT DEFAULT "LEGIT"',
        );
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN risk_score REAL');
      } catch (e) {}
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN user_location TEXT DEFAULT ""',
        );
      } catch (e) {}
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN network_type TEXT DEFAULT "4G"',
        );
      } catch (e) {}
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN sync_status TEXT DEFAULT "pending"',
        );
      } catch (e) {}
    }
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
    return {for (var c in contacts) c.localId!: c};
  }

  Future<Contact?> getContactByLocalId(int id) async {
    final db = await database;
    final maps = await db.query(
      'contacts',
      where: 'local_id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return Contact.fromMap(maps.first);
    return null;
  }

  Future<Contact?> getContactByVpa(String vpa) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'contacts',
      where: 'vpa = ?',
      whereArgs: [vpa],
    );
    if (result.isNotEmpty) return Contact.fromMap(result.first);
    return null;
  }

  Future<Contact?> getContactByDjangoId(String djangoId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'contacts',
      where: 'django_id = ?',
      whereArgs: [djangoId],
    );
    if (result.isNotEmpty) return Contact.fromMap(result.first);
    return null;
  }

  Future<int> updateContact(Contact contact) async {
    final db = await database;
    return await db.update(
      'contacts',
      contact.toMap(),
      where: 'local_id = ?',
      whereArgs: [contact.localId],
    );
  }

  Future<int> deleteContact(int localId) async {
    final db = await database;
    return await db.delete(
      'contacts',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> insertOrUpdateContact(Contact contact) async {
    final db = await database;
    await db.insert(
      'contacts',
      contact.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateContactLastPaid(String vpa) async {
    final db = await database;
    await db.update(
      'contacts',
      {'last_paid_at': DateTime.now().toIso8601String()},
      where: 'vpa = ?',
      whereArgs: [vpa],
    );
  }

  Future<List<Contact>> getRecentContacts({int limit = 15}) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'contacts',
      orderBy: 'last_paid_at DESC NULLS LAST',
      limit: limit,
    );
    return result.map((map) => Contact.fromMap(map)).toList();
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
      where: onlyFraud ? 'fraud_status = "FRAUD"' : null,
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

  Future<void> updateTransactionStatus(
    String transactionId,
    String status,
  ) async {
    final db = await database;
    await db.update(
      'transactions',
      {'status': status},
      where: 'id = ?',
      whereArgs: [transactionId],
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
      {
        'fraud_status': isFraud ? 'FRAUD' : 'LEGIT',
        'risk_factors': riskFactors,
      },
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<int> deleteTransaction(String id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<tx.Transaction>> getPendingSyncTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'transactions',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );
    return result.map((map) => tx.Transaction.fromMap(map)).toList();
  }

  Future<void> updateTransactionSyncStatus(
    String transactionId,
    String syncStatus,
  ) async {
    final db = await database;
    await db.update(
      'transactions',
      {'sync_status': syncStatus},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('contacts');
    await db.delete('messages');
    await db.delete('fraud_flags');
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

  Future<List<Message>> getAllMessages() async {
    final db = await database;
    final maps = await db.query('messages', orderBy: 'timestamp DESC');
    return maps.map((map) => Message.fromMap(map)).toList();
  }

  Future<int> updateMessage(Message message) async {
    final db = await database;
    return await db.update(
      'messages',
      message.toMap(),
      where: 'id = ?',
      whereArgs: [message.id],
    );
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
