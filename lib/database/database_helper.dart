// database/database_helper.dart

import 'package:fraudguard_pay/models/message_model.dart';
import 'package:fraudguard_pay/services/user_manager.dart';
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
    final maps = await db.query(
      'contacts',
      where: 'local_id != 0',
      orderBy: 'name ASC',
    );
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
      where: 'local_id != 0',
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

  // ── Contact helpers ────────────────────────────────────────────────────────

  /// Insert or update a contact by VPA (unique key).
  /// Returns the local_id of the inserted/updated row.
  Future<int> insertOrUpdateContactReturningId(Contact contact) async {
    final db = await database;

    // Check if contact with this VPA already exists
    final existing = await db.query(
      'contacts',
      where: 'vpa = ?',
      whereArgs: [contact.vpa],
      columns: ['local_id'],
    );

    if (existing.isNotEmpty) {
      final localId = existing.first['local_id'] as int;
      // Update fields but preserve local_id
      await db.update(
        'contacts',
        {
          'name': contact.name,
          'phone': contact.phone,
          'is_verified': contact.isVerified ? 1 : 0,
          'is_merchant': contact.isMerchant ? 1 : 0,
          'django_id': contact.djangoId,
          // do NOT overwrite last_paid_at during sync
        },
        where: 'vpa = ?',
        whereArgs: [contact.vpa],
      );
      return localId;
    } else {
      return await db.insert('contacts', contact.toMap());
    }
  }

  /// Ensure a "me" sentinel row exists for the current user.
  /// We store this with django_id = userId and vpa = '__me__'
  /// so transactions can reference senderContactId = 0.
  /// (SQLite AUTOINCREMENT starts at 1, so 0 is never assigned naturally.)
  Future<void> ensureMeContact(String myUserId) async {
    final db = await database;
    final name = await UserManager.getUserName();
    final vpa = await UserManager.getUserVpa();

    // We store in contacts with django_id = myUserId so lookups work,
    // but we DO NOT give it an autoincrement id — we use raw insert with id 0.
    // SQLite allows explicit rowid = 0 when using INTEGER PRIMARY KEY.
    final existing = await db.query(
      'contacts',
      where: 'django_id = ?',
      whereArgs: [myUserId],
    );
    if (existing.isEmpty) {
      await db.rawInsert(
        '''INSERT OR IGNORE INTO contacts
           (local_id, name, vpa, phone, is_verified, is_merchant, django_id)
           VALUES (0, ?, ?, '', 1, 0, ?)''',
        [name, vpa.isNotEmpty ? vpa : '__me__', myUserId],
      );
    }
  }

  /// Look up a contact's local_id by their django_id.
  Future<int?> getLocalIdByDjangoId(String djangoId) async {
    if (djangoId.isEmpty) return null;
    final db = await database;
    final result = await db.query(
      'contacts',
      columns: ['local_id'],
      where: 'django_id = ?',
      whereArgs: [djangoId],
    );
    if (result.isNotEmpty) return result.first['local_id'] as int;
    return null;
  }

  // ── Transaction helpers ───────────────────────────────────────────────────

  /// Get all transactions involving a contact (sent to OR received from).
  Future<List<tx.Transaction>> getTransactionsForContact(
    int contactLocalId,
  ) async {
    // Prevent self sentinal
    if (contactLocalId <= 0) return [];

    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'sender_contact_id = ? OR recipient_contact_id = ?',
      whereArgs: [contactLocalId, contactLocalId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => tx.Transaction.fromMap(m)).toList();
  }

  /// Update both status and fraud_status in one call.
  Future<void> updateTransactionStatuses(
    String transactionId, {
    required String status,
    required String fraudStatus,
  }) async {
    final db = await database;
    await db.update(
      'transactions',
      {'status': status, 'fraud_status': fraudStatus},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }
}
