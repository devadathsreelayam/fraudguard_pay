// services/sync_manager.dart
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:fraudguard_pay/services/api_service.dart';
import 'package:fraudguard_pay/services/user_manager.dart';

class SyncManager {
  final ApiService _api = ApiService();
  final DatabaseHelper _db = DatabaseHelper();

  // ── Public entry points ──────────────────────────────────────────────────

  /// Full sync: call on launch and on pull-to-refresh.
  Future<SyncResult> syncAll(String userId) async {
    try {
      print('🔄 Starting sync for user: $userId');
      final result = await _api.syncCustomerData(userId);

      if (result['success'] != true) {
        return SyncResult.failure(result['error'] ?? 'Unknown error');
      }
      final data = result['data'] as Map<String, dynamic>;
      await _processSync(data, userId);

      final contactsCount = (data['contacts'] as List?)?.length ?? 0;
      final transactionsCount = (data['transactions'] as List?)?.length ?? 0;
      print(
        '✅ Sync completed: $contactsCount contacts, $transactionsCount transactions',
      );

      return SyncResult.success(
        contactsUpdated: contactsCount,
        transactionsUpdated: transactionsCount,
      );
    } catch (e) {
      print('❌ Sync failed: $e');
      return SyncResult.failure(e.toString());
    }
  }

  // ── Core processing ──────────────────────────────────────────────────────

  Future<void> _processSync(
    Map<String, dynamic> data,
    String loggedInUserId,
  ) async {
    print('📦 Processing sync data for user: $loggedInUserId');

    // 1. Save/update all contacts FIRST (transactions reference them)
    final contactsList = data['contacts'] as List? ?? [];
    final djangoIdToLocalId = <String, int>{};

    print('📇 Processing ${contactsList.length} contacts...');

    for (final c in contactsList) {
      final contactDjangoId = c['django_id'] as String? ?? '';

      // Skip if this contact is the user themselves
      if (contactDjangoId == loggedInUserId) {
        print(
          '   ⏭️ Skipping self-contact: ${c['name']} (django_id: $contactDjangoId)',
        );
        continue;
      }

      // Also skip if VPA is the user's own VPA (fallback check)
      final userVpa = await UserManager.getUserVpa();
      if (c['vpa'] == userVpa) {
        print(
          '   ⏭️ Skipping self-contact by VPA: ${c['name']} (vpa: ${c['vpa']})',
        );
        continue;
      }

      final contact = Contact(
        name: c['name'] ?? 'Unknown',
        vpa: c['vpa'] ?? '',
        phone: c['phone'] ?? '',
        isVerified: c['is_verified'] == true,
        isMerchant: c['type'] == 'MERCHANT',
        djangoId: contactDjangoId,
      );

      // insertOrUpdateContact returns the local_id (new or existing)
      final localId = await _db.insertOrUpdateContactReturningId(contact);
      if (contactDjangoId.isNotEmpty) {
        djangoIdToLocalId[contactDjangoId] = localId;
      }
      print(
        '   ✅ Saved contact: ${contact.name} (local_id: $localId, django_id: $contactDjangoId)',
      );
    }

    // 2. Save user's own "me" contact if not present (localId = 0 sentinel)
    await _db.ensureMeContact(loggedInUserId);
    print('✅ Ensured "me" contact exists');

    // 3. Save transactions with correct direction
    final txnList = data['transactions'] as List? ?? [];
    print('💸 Processing ${txnList.length} transactions...');

    int savedCount = 0;
    int skippedCount = 0;

    for (final t in txnList) {
      try {
        final direction = t['direction'] as String? ?? 'SENT';
        final otherPartyId = t['other_party_id'] as String? ?? '';
        final isSent = direction == 'SENT';

        // Skip transactions where other party is the user themselves (shouldn't happen)
        if (otherPartyId == loggedInUserId) {
          print('   ⏭️ Skipping self-transaction: $direction to self');
          skippedCount++;
          continue;
        }

        // Resolve the other party's localId
        int otherLocalId = -1;

        // First try from the map we built
        if (djangoIdToLocalId.containsKey(otherPartyId)) {
          otherLocalId = djangoIdToLocalId[otherPartyId]!;
        } else {
          // Then try database lookup
          otherLocalId = await _db.getLocalIdByDjangoId(otherPartyId) ?? -1;
        }

        if (otherLocalId == -1) {
          print(
            '   ⚠️ Warning: Could not find contact for django_id: $otherPartyId',
          );
        }

        final senderContactId = isSent ? 0 : otherLocalId;
        final recipientContactId = isSent ? otherLocalId : 0;

        final txn = Transaction(
          id: t['txn_id'] ?? t['id'] ?? '',
          timestamp: DateTime.parse(t['timestamp']),
          senderContactId: senderContactId,
          recipientContactId: recipientContactId,
          amount: (t['amount'] as num).toDouble(),
          transactionType:
              t['transaction_type'] ?? Transaction.TRANSACTION_TYPE_P2M,
          recipientType:
              t['recipient_type'] ?? Transaction.RECIPIENT_TYPE_MERCHANT,
          status: t['status'] ?? Transaction.STATUS_SUCCESS,
          fraudStatus: t['fraud_status'] ?? Transaction.FRAUD_LEGIT,
          note: t['note'],
          riskScore:
              t['risk_score'] != null
                  ? (t['risk_score'] as num).toDouble()
                  : null,
          userLocation: t['user_location'] ?? '',
          networkType: t['network_type'] ?? '4G',
          syncStatus: Transaction.SYNC_SYNCED,
        );

        if (txn.id.isNotEmpty) {
          await _db.insertTransaction(txn);
          savedCount++;
          if (savedCount <= 5) {
            print(
              '   ✅ Saved transaction: ${txn.id} - ${isSent ? "SENT" : "RECEIVED"} - ₹${txn.amount}',
            );
          }
        }
      } catch (e) {
        print('   ❌ Error saving transaction: $e');
        skippedCount++;
      }
    }

    print('📊 Transaction summary: $savedCount saved, $skippedCount skipped');

    // 4. Save profile info locally
    final profile = data['customer_profile'] as Map?;
    if (profile != null) {
      await _saveProfileLocally(profile);
      print('✅ Profile saved locally');
    }

    // 5. Debug: Print all contacts after sync
    final allContacts = await _db.getContacts();
    print('📇 Final contacts in DB (${allContacts.length}):');
    for (var c in allContacts) {
      print(
        '   - local_id: ${c.localId}, name: ${c.name}, django_id: ${c.djangoId}, isMerchant: ${c.isMerchant}',
      );
    }
  }

  Future<void> _saveProfileLocally(Map profile) async {
    await UserManager.setUserName(profile['name'] ?? 'User');
    await UserManager.setUserVpa(profile['vpa'] ?? '');
  }
}

// ── Result object ──────────────────────────────────────────────────────────

class SyncResult {
  final bool success;
  final String? error;
  final int contactsUpdated;
  final int transactionsUpdated;

  SyncResult._({
    required this.success,
    this.error,
    this.contactsUpdated = 0,
    this.transactionsUpdated = 0,
  });

  factory SyncResult.success({
    int contactsUpdated = 0,
    int transactionsUpdated = 0,
  }) => SyncResult._(
    success: true,
    contactsUpdated: contactsUpdated,
    transactionsUpdated: transactionsUpdated,
  );

  factory SyncResult.failure(String error) =>
      SyncResult._(success: false, error: error);
}
