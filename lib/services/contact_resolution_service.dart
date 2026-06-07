import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/services/api_service.dart';

/// services/contact_resolution_service.dart

class ContactResolutionService {
  final ApiService _api = ApiService();
  final DatabaseHelper _db = DatabaseHelper();

  /// Resolve a contact by VPA - checks local cache first, then Django
  Future<Contact> resolveContact({
    required String vpa,
    required String name,
    required String phone,
  }) async {
    // 1. Check local cache
    final localContact = await _db.getContactByVpa(vpa);

    if (localContact != null && localContact.djangoId != null) {
      // Already resolved, update last used time
      await _db.updateContactLastPaid(vpa);
      return localContact;
    }

    // 2. Call Django resolve endpoint
    try {
      final result = await _api.resolveVpa(vpa, name: name);

      if (result['success'] && result['data']['found'] == true) {
        final data = result['data'];
        final profile = data['profile'];
        final isMerchant = data['type'] == 'MERCHANT';

        // Create or update contact
        final contact = Contact(
          name: profile['name'] ?? name,
          vpa: vpa,
          phone: profile['phone'] ?? phone,
          isVerified: profile['verified'] == true || !isMerchant,
          isMerchant: isMerchant,
          djangoId: data['django_id'],
          lastPaidAt: DateTime.now(),
        );

        await _db.insertOrUpdateContact(contact);
        return contact;
      } else {
        // Not found in Django - create local stub (unverified)
        final contact = Contact(
          name: name,
          vpa: vpa,
          phone: phone,
          isVerified: false,
          isMerchant: true,
          djangoId: null,
          lastPaidAt: DateTime.now(),
        );

        await _db.insertOrUpdateContact(contact);
        return contact;
      }
    } catch (e) {
      // API error - use cached or create temporary
      if (localContact != null) {
        await _db.updateContactLastPaid(vpa);
        return localContact;
      }

      // Create temporary unverified contact
      final tempContact = Contact(
        name: name,
        vpa: vpa,
        phone: phone,
        isVerified: false,
        isMerchant: true,
        djangoId: null,
        lastPaidAt: DateTime.now(),
      );
      await _db.insertOrUpdateContact(tempContact);
      return tempContact;
    }
  }

  /// Get recently paid contacts (for home screen)
  Future<List<Contact>> getRecentContacts({int limit = 15}) async {
    return await _db.getRecentContacts(limit: limit);
  }
}
