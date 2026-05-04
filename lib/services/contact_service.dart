import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:fraudguard_pay/models/app_state_model.dart';

// ============================================================================
// CONTACT SERVICE
// Provides business logic for contact management.
// ============================================================================

class ContactService {
  static final ContactService _instance = ContactService._internal();

  factory ContactService() {
    return _instance;
  }

  ContactService._internal();

  /// Get all contacts
  List<Contact> getAllContacts() {
    return List<Contact>.from(contacts);
  }

  /// Get contact by name
  Contact? getContactByName(String name) {
    try {
      return contacts.firstWhere(
        (contact) => contact.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get contact by number
  Contact? getContactByNumber(String number) {
    try {
      return contacts.firstWhere((contact) => contact.phone == number);
    } catch (e) {
      return null;
    }
  }

  /// Get transaction history for a contact
  List<Transaction> getContactHistory(Contact contact) {
    return contact.getHistory(transactionHistory);
  }

  /// Get last transaction with a contact
  Transaction? getLastTransaction(Contact contact) {
    return contact.lastTransaction(transactionHistory);
  }

  /// Add a new contact
  void addContact(Contact contact) {
    if (contacts.any(
      (c) => c.name.toLowerCase() == contact.name.toLowerCase(),
    )) {
      throw Exception("Contact already exists");
    }
    contacts.add(contact);
  }

  /// Delete a contact by name
  void deleteContact(String name) {
    contacts.removeWhere(
      (contact) => contact.name.toLowerCase() == name.toLowerCase(),
    );
  }

  /// Search contacts by name
  List<Contact> searchContacts(String query) {
    return contacts
        .where(
          (contact) => contact.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  /// Get contacts sorted by recent transaction
  List<Contact> getContactsSortedByRecent() {
    final sorted = List<Contact>.from(contacts);
    sorted.sort((a, b) {
      final lastTxnA = a.lastTransaction(transactionHistory);
      final lastTxnB = b.lastTransaction(transactionHistory);

      if (lastTxnA == null && lastTxnB == null) return 0;
      if (lastTxnA == null) return 1;
      if (lastTxnB == null) return -1;

      return lastTxnB.timestamp.compareTo(lastTxnA.timestamp);
    });
    return sorted;
  }
}
