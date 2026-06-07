import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:fraudguard_pay/services/api_service.dart';

class SyncManager {
  final ApiService _api = ApiService();
  final DatabaseHelper _db = DatabaseHelper();

  Future<void> syncOnLaunch(String userId) async {
    try {
      print('🔄 Starting sync for user: $userId');
      await _downloadLatestCache(userId);
      print('✅ Sync completed successfully');
    } catch (e) {
      print('❌ Sync on launch failed: $e');
    }
  }

  Future<void> _downloadLatestCache(String userId) async {
    try {
      print('📥 Downloading cache for user: $userId');
      final result = await _api.syncCustomerData(userId);

      print('📦 API Response success: ${result['success']}');

      if (result['success'] == true) {
        final data = result['data'];

        print('📊 Data received:');
        print('   - Contacts: ${data['recent_contacts']?.length ?? 0}');
        print('   - Transactions: ${data['transactions']?.length ?? 0}');

        // Save recent contacts
        final contactsList = data['recent_contacts'] as List?;
        if (contactsList != null && contactsList.isNotEmpty) {
          print('💾 Saving ${contactsList.length} contacts...');
          for (var c in contactsList) {
            try {
              final contact = Contact(
                name: c['name'] ?? 'Unknown',
                vpa: c['vpa'] ?? '',
                phone: '', // Phone not provided in this response
                isVerified:
                    c['type'] == 'MERCHANT'
                        ? false
                        : true, // Customers are verified, merchants not by default
                isMerchant: c['type'] == 'MERCHANT',
                djangoId: c['id'],
                lastPaidAt:
                    c['last_transaction_date'] != null
                        ? DateTime.parse(c['last_transaction_date'])
                        : null,
              );
              await _db.insertOrUpdateContact(contact);
              print('   ✓ Saved contact: ${contact.name} (${contact.vpa})');
            } catch (e) {
              print('   ✗ Error saving contact: $e');
            }
          }
        }

        // Save transactions
        final transactionsList = data['transactions'] as List?;
        if (transactionsList != null && transactionsList.isNotEmpty) {
          print('💾 Saving ${transactionsList.length} transactions...');
          for (var t in transactionsList) {
            try {
              // Parse the transaction - note the field names from API
              final transaction = Transaction(
                id: t['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                timestamp: DateTime.parse(t['timestamp']),
                senderContactId:
                    0, // Current user is sender if user_id matches, otherwise recipient
                recipientContactId: 0, // We'll determine this from contacts
                amount: (t['amount'] as num).toDouble(),
                transactionType:
                    t['transaction_type'] ?? Transaction.TRANSACTION_TYPE_P2M,
                recipientType:
                    t['recipient_type'] == 'CUSTOMER'
                        ? Transaction.RECIPIENT_TYPE_CUSTOMER
                        : Transaction.RECIPIENT_TYPE_MERCHANT,
                status: t['status'] ?? Transaction.STATUS_PENDING,
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

              // Determine sender and recipient contacts
              // For now, we'll map recipient_id to a contact
              final recipientIdStr = t['recipient_id'];
              if (recipientIdStr != null) {
                // Try to find contact by django_id
                final existingContact = await _db.getContactByDjangoId(
                  recipientIdStr,
                );
                if (existingContact != null &&
                    existingContact.localId != null) {
                  // This is a transaction involving this contact
                  // We need to set senderContactId and recipientContactId properly
                  // For simplicity, we'll store recipientContactId and assume sender is current user
                  final updatedTransaction = transaction.copyWith(
                    recipientContactId: existingContact.localId!,
                  );
                  await _db.insertTransaction(updatedTransaction);
                } else {
                  await _db.insertTransaction(transaction);
                }
              } else {
                await _db.insertTransaction(transaction);
              }
              print(
                '   ✓ Saved transaction: ${transaction.id} - ₹${transaction.amount}',
              );
            } catch (e) {
              print('   ✗ Error saving transaction: ${t['id']} - $e');
            }
          }
        } else {
          print('⚠️ No transactions received from server');
        }

        // Verify data was saved
        final savedContacts = await _db.getContacts();
        final savedTransactions = await _db.getTransactions();
        print('📊 Database after sync:');
        print('   - Contacts: ${savedContacts.length}');
        print('   - Transactions: ${savedTransactions.length}');
      } else {
        print('❌ Sync failed: ${result['error']}');
      }
    } catch (e) {
      print('❌ Error downloading cache: $e');
      print('StackTrace: ${StackTrace.current}');
    }
  }
}
