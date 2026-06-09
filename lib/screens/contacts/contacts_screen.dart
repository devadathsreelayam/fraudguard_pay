import 'package:flutter/material.dart';
import 'package:fraudguard_pay/config/theme.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/screens/contacts/contact_chat_screen.dart';
import 'package:intl/intl.dart';

// contacts_screen.dart
/// Contacts screen showing list of frequent contacts for payments.
/// Flows: Home → Contacts Screen → Payment Detail Screen
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadContacts();
  }

  final TextEditingController _searchController = TextEditingController();
  bool _isNumericKeyboard = false;
  bool _isLoading = true;

  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  Map<int, DateTime?> _lastTransactionDates = {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);

    final dbHelper = DatabaseHelper();

    // Get recent contacts (sorted by last_paid_at)
    final contactsFromDb = await dbHelper.getRecentContacts(limit: 50);

    // Get all transactions to compute last transaction dates
    final allTransactions = await dbHelper.getTransactions();

    // Build a map of contact ID -> last transaction date
    final Map<int, DateTime> lastTxnMap = {};
    for (var txn in allTransactions) {
      // Check both sender and recipient
      if (txn.recipientContactId > 0) {
        final existing = lastTxnMap[txn.recipientContactId];
        if (existing == null || txn.timestamp.isAfter(existing)) {
          lastTxnMap[txn.recipientContactId] = txn.timestamp;
        }
      }
      if (txn.senderContactId > 0) {
        final existing = lastTxnMap[txn.senderContactId];
        if (existing == null || txn.timestamp.isAfter(existing)) {
          lastTxnMap[txn.senderContactId] = txn.timestamp;
        }
      }
    }

    setState(() {
      _allContacts = contactsFromDb;
      _lastTransactionDates = lastTxnMap.map(
        (key, value) => MapEntry(key, value),
      );
      _filterContacts(_searchController.text);
      _isLoading = false;
    });
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = List.from(_allContacts);
      } else {
        _filteredContacts =
            _allContacts.where((c) {
              final nameMatch = c.name.toLowerCase().contains(
                query.toLowerCase(),
              );
              final phoneMatch = c.phone.contains(query);
              final vpaMatch = c.vpa.toLowerCase().contains(
                query.toLowerCase(),
              );
              return nameMatch || phoneMatch || vpaMatch;
            }).toList();
      }
    });
  }

  Future<void> _refreshAfterReturn() async {
    await _loadContacts();
  }

  DateTime? _getLastTransactionDate(Contact contact) {
    if (contact.localId == null) return null;
    return _lastTransactionDates[contact.localId];
  }

  Widget _buildVerificationBadge(Contact contact) {
    if (!contact.isMerchant || !contact.isVerified) {
      return const SizedBox.shrink();
    }

    return Icon(Icons.verified, color: Colors.green, size: 13);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        backgroundColor: primaryDark,
        elevation: 0,
        title: const Text(
          "Pay Contacts",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(color: accentOrange),
                    )
                    : _filteredContacts.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.contacts_outlined,
                            size: 64,
                            color: textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? "No contacts yet"
                                : "No matching contacts",
                            style: const TextStyle(color: textSecondary),
                          ),
                          if (_searchController.text.isEmpty)
                            const SizedBox(height: 8),
                          if (_searchController.text.isEmpty)
                            const Text(
                              "Make a payment to someone to add them here",
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = _filteredContacts[index];
                        final lastTxnDate = _getLastTransactionDate(contact);
                        final hasHistory = lastTxnDate != null;

                        return ListTile(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ContactChatScreen(contact: contact),
                              ),
                            );
                            _refreshAfterReturn();
                          },
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: secondaryDark,
                                radius: 24,
                                child: Text(
                                  contact.name.isNotEmpty
                                      ? contact.name[0].toUpperCase()
                                      : "?",
                                  style: const TextStyle(
                                    color: accentOrange,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          title: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  contact.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              _buildVerificationBadge(contact),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.vpa,
                                style: const TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              if (contact.phone.isNotEmpty)
                                Text(
                                  contact.phone,
                                  style: const TextStyle(
                                    color: textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: Icon(Icons.search, color: textSecondary),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _filterContacts,
                keyboardType:
                    _isNumericKeyboard
                        ? TextInputType.number
                        : TextInputType.text,
                key: ValueKey(_isNumericKeyboard),
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Search name, VPA or number",
                  hintStyle: TextStyle(color: textSecondary),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, color: textSecondary, size: 18),
                onPressed: () {
                  _searchController.clear();
                  _filterContacts('');
                },
              ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: secondaryDark,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  _keyboardToggleBtn("123", true),
                  _keyboardToggleBtn("ABC", false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _keyboardToggleBtn(String label, bool isNumeric) {
    final bool isSelected = _isNumericKeyboard == isNumeric;
    return GestureDetector(
      onTap: () => setState(() => _isNumericKeyboard = isNumeric),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
