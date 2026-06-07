// fraud_details_screen.dart

import 'package:flutter/material.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
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
  List<Transaction> _allFraudTransactions = [];
  List<Transaction> _filteredFraud = [];
  Map<int, Contact> _contactsMap = {};
  final TextEditingController _searchController = TextEditingController();
  String selectedStatus = "All"; // All, Blocked, Flagged
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final dbHelper = DatabaseHelper();
    final contacts = await dbHelper.getContacts();

    // Get all fraud/flagged transactions
    final allTransactions = await dbHelper.getTransactions();
    final fraudTransactions =
        allTransactions
            .where(
              (txn) =>
                  txn.fraudStatus == Transaction.FRAUD_FRAUD ||
                  txn.fraudStatus == Transaction.FRAUD_REVIEW,
            )
            .toList();

    // Build map of localId -> Contact
    final Map<int, Contact> contactsMap = {};
    for (var c in contacts) {
      if (c.localId != null) {
        contactsMap[c.localId!] = c;
      }
    }

    setState(() {
      _contactsMap = contactsMap;
      _allFraudTransactions = fraudTransactions;
      _filteredFraud = List.from(fraudTransactions);
      _isLoading = false;
    });
  }

  void _runFilter() {
    String keyword = _searchController.text.toLowerCase();

    setState(() {
      _filteredFraud =
          _allFraudTransactions.where((txn) {
            // Determine display contact based on transaction direction
            final int displayContactId =
                txn.isSent ? txn.recipientContactId : txn.senderContactId;

            final Contact? contact = _contactsMap[displayContactId];
            final String displayName =
                contact?.name ??
                (displayContactId > 0 ? "Unknown User" : "You");
            final String displayVpa = contact?.vpa ?? "";

            // Search match
            bool matchesSearch =
                keyword.isEmpty ||
                displayName.toLowerCase().contains(keyword) ||
                displayVpa.toLowerCase().contains(keyword) ||
                txn.amount.toString().contains(keyword);

            // Status Match
            bool matchesStatus = selectedStatus == "All";
            if (!matchesStatus) {
              if (selectedStatus == "Blocked") {
                matchesStatus = txn.fraudStatus == Transaction.FRAUD_FRAUD;
              } else if (selectedStatus == "Flagged") {
                matchesStatus = txn.fraudStatus == Transaction.FRAUD_REVIEW;
              }
            }

            return matchesSearch && matchesStatus;
          }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: const Text("Security Log"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: accentOrange),
              )
              : Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => _runFilter(),
                      style: const TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: "Search by name, VPA or amount...",
                        hintStyle: const TextStyle(
                          color: textSecondary,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.security,
                          color: textSecondary,
                        ),
                        suffixIcon:
                            _searchController.text.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _runFilter();
                                  },
                                )
                                : null,
                        filled: true,
                        fillColor: cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  // Filter Chips
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
                                  color:
                                      isSelected ? accentOrange : textSecondary,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),

                  // Summary Stats
                  if (_allFraudTransactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _buildStatChip(
                            "Total Threats",
                            _allFraudTransactions.length.toString(),
                            Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          _buildStatChip(
                            "Blocked",
                            _allFraudTransactions
                                .where(
                                  (t) =>
                                      t.fraudStatus == Transaction.FRAUD_FRAUD,
                                )
                                .length
                                .toString(),
                            Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          _buildStatChip(
                            "Flagged",
                            _allFraudTransactions
                                .where(
                                  (t) =>
                                      t.fraudStatus == Transaction.FRAUD_REVIEW,
                                )
                                .length
                                .toString(),
                            Colors.amber,
                          ),
                        ],
                      ),
                    ),

                  // The List
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

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: textSecondary, fontSize: 11)),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFraudItem(Transaction txn) {
    final bool isBlocked = txn.fraudStatus == Transaction.FRAUD_FRAUD;
    final bool isReview = txn.fraudStatus == Transaction.FRAUD_REVIEW;

    // Determine display contact
    final int displayContactId =
        txn.isSent ? txn.recipientContactId : txn.senderContactId;

    final Contact? contact = _contactsMap[displayContactId];
    final String displayName =
        contact?.name ?? (displayContactId > 0 ? "Unknown User" : "You");
    final String displayVpa = contact?.vpa ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isBlocked
                  ? Colors.redAccent.withOpacity(0.3)
                  : Colors.amber.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              isBlocked
                  ? Colors.redAccent.withOpacity(0.1)
                  : Colors.amber.withOpacity(0.1),
          child: Icon(
            isBlocked ? Icons.block_flipped : Icons.flag_rounded,
            color: isBlocked ? Colors.redAccent : Colors.amber,
            size: 24,
          ),
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (displayVpa.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  displayVpa,
                  style: const TextStyle(color: textSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(txn.timestamp),
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
            if (txn.note != null && txn.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "Note: ${txn.note}",
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "₹${txn.amount.toStringAsFixed(2)}",
              style: const TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:
                    isBlocked
                        ? Colors.redAccent.withOpacity(0.2)
                        : Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isBlocked ? "BLOCKED" : "FLAGGED",
                style: TextStyle(
                  color: isBlocked ? Colors.redAccent : Colors.amber,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (txn.riskScore != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "Risk: ${(txn.riskScore! * 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                    color: isBlocked ? Colors.redAccent : Colors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
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
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 80,
            color: Colors.greenAccent.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            "No suspicious activity found",
            style: TextStyle(color: textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            "Your transactions are secure",
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text("Refresh"),
            style: ElevatedButton.styleFrom(backgroundColor: accentOrange),
          ),
        ],
      ),
    );
  }
}
