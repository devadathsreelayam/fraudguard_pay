import 'package:flutter/material.dart';
import 'package:fraudguard_pay/config/theme.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/app_state_model.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/screens/contacts/contact_detail/payment_detail_screen.dart';
import 'package:intl/intl.dart';

/// Contacts screen showing list of frequent contacts for payments.
/// Flows: Home → Contacts Screen → Payment Detail Screen
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isNumericKeyboard = false;

  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final dbHelper = DatabaseHelper();
    final contactsFromDb = await dbHelper.getContacts();
    setState(() {
      _allContacts = contactsFromDb;
      _filterContacts(_searchController.text);
    });
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = List.from(_allContacts);
      } else {
        _filteredContacts =
            _allContacts
                .where(
                  (c) =>
                      c.name.toLowerCase().contains(query.toLowerCase()) ||
                      c.phone.contains(query),
                )
                .toList();
      }
    });
  }

  Future<void> _refreshAfterReturn() async {
    await _loadContacts();
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
                _filteredContacts.isEmpty
                    ? const Center(
                      child: Text(
                        "No contacts found",
                        style: TextStyle(color: textSecondary),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = _filteredContacts[index];
                        final lastTxn = contact.lastTransaction(
                          transactionHistory,
                          myContactId: 0,
                        );
                        final hasHistory = lastTxn != null;

                        return ListTile(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        PaymentDetailScreen(contact: contact),
                              ),
                            );
                            // Refresh contacts after returning (new contact may have been added)
                            _refreshAfterReturn();
                          },
                          leading: CircleAvatar(
                            backgroundColor: secondaryDark,
                            child: Text(
                              contact.name[0],
                              style: const TextStyle(color: accentOrange),
                            ),
                          ),
                          title: Text(
                            contact.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            contact.phone,
                            style: TextStyle(
                              color:
                                  hasHistory ? Colors.white70 : textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          trailing:
                              hasHistory
                                  ? Text(
                                    DateFormat(
                                      'dd/MM',
                                    ).format(lastTxn.timestamp),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  )
                                  : null,
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
                  hintText: "Search name or number",
                  hintStyle: TextStyle(color: textSecondary),
                  border: InputBorder.none,
                ),
              ),
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
