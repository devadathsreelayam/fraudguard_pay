import 'package:flutter/material.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/app_state_model.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:fraudguard_pay/widgets/theme.dart';
import 'package:intl/intl.dart';

class FraudDetailsScreen extends StatefulWidget {
  const FraudDetailsScreen({super.key});

  @override
  State<FraudDetailsScreen> createState() => _FraudDetailsScreenState();
}

class _FraudDetailsScreenState extends State<FraudDetailsScreen> {
  List<Transaction> _filteredFraud = [];
  Map<int, Contact> _contactsMap = {};
  final TextEditingController _searchController = TextEditingController();
  String selectedStatus = "All"; // All, Blocked, Flagged

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _filteredFraud = fraudHistory;
  }

  Future<void> _loadContacts() async {
    final dbHelper = DatabaseHelper();
    final contacts = await dbHelper.getContacts();
    setState(() {
      _contactsMap = {for (var c in contacts) c.id!: c};
    });
  }

  void _runFilter() {
    String keyword = _searchController.text.toLowerCase();
    setState(() {
      _filteredFraud =
          fraudHistory.where((txn) {
            String displayName =
                _contactsMap[txn.recipientContactId]?.name ?? "Unknown";
            bool matchesSearch =
                displayName.toLowerCase().contains(keyword) ||
                txn.amount.toString().contains(keyword);

            // Status Match: We treat anything not 'Blocked' as 'Flagged'
            bool matchesStatus =
                selectedStatus == "All" ||
                (selectedStatus == "Blocked" &&
                    txn.status.toLowerCase() == "blocked") ||
                (selectedStatus == "Flagged" &&
                    txn.status.toLowerCase() != "blocked");

            return matchesSearch && matchesStatus;
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: const Text("Security Log"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Search Bar (Reusing your style)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _runFilter(),
              style: const TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: "Search threats by name or amount...",
                hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
                prefixIcon: const Icon(Icons.security, color: textSecondary),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 2. Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children:
                  ["All", "Blocked", "Flagged"].map((status) {
                    final isSelected = selectedStatus == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(status),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() => selectedStatus = status);
                          _runFilter();
                        },
                        selectedColor: accentOrange.withOpacity(0.2),
                        backgroundColor: cardBg,
                        labelStyle: TextStyle(
                          color: isSelected ? accentOrange : textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),

          // 3. The List
          Expanded(
            child:
                _filteredFraud.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredFraud.length,
                      itemBuilder:
                          (context, index) =>
                              _buildFraudItem(_filteredFraud[index]),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildFraudItem(Transaction txn) {
    bool isBlocked = txn.status.toLowerCase() == 'blocked';

    String displayName =
        _contactsMap[txn.recipientContactId]?.name ?? "Unknown";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isBlocked
                  ? Colors.redAccent.withValues(alpha: 0.3)
                  : Colors.amber.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isBlocked
                  ? Colors.redAccent.withValues(alpha: 0.1)
                  : Colors.amber.withValues(alpha: 0.1),
          child: Icon(
            isBlocked ? Icons.block_flipped : Icons.flag_rounded,
            color: isBlocked ? Colors.redAccent : Colors.amber,
          ),
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          DateFormat('dd MMM, hh:mm a').format(txn.timestamp),
          style: const TextStyle(color: textSecondary, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "₹${txn.amount}",
              style: const TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              isBlocked ? "BLOCKED" : "FLAGGED",
              style: TextStyle(
                color: isBlocked ? Colors.redAccent : Colors.amber,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.verified_user_outlined,
            size: 64,
            color: Colors.greenAccent,
          ),
          SizedBox(height: 16),
          Text(
            "No suspicious activity found",
            style: TextStyle(color: textSecondary),
          ),
        ],
      ),
    );
  }
}
