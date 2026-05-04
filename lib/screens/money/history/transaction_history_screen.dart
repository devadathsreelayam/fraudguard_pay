import 'package:flutter/material.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:fraudguard_pay/config/theme.dart';
import 'package:fraudguard_pay/models/app_state_model.dart';
import 'package:intl/intl.dart';

/// Transaction history screen with search and filtering capabilities.
/// Flows: Home/Money → Transaction History → {Filter by status/date/amount}
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<Transaction> _filteredTransactions = [];
  final TextEditingController _searchController = TextEditingController();
  Map<int, Contact> _contactsMap = {};

  String selectedStatus = "All";
  String selectedDateRange = "All";
  String selectedAmountRange = "All";
  String selectedPaymentType = "All";
  String tempSelection = "";

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _filteredTransactions = transactionHistory;
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

    List<Transaction> results =
        transactionHistory.where((txn) {
          // 1. Search Text Match
          bool isReceived = txn.type == "Money Recceived";
          int displayContactId =
              isReceived ? txn.senderContactId : txn.recipientContactId;
          String displayName =
              _contactsMap[displayContactId]?.name ?? "Unknown";
          bool matchesSearch =
              displayName.toLowerCase().contains(keyword) ||
              txn.amount.toString().contains(keyword);

          // 2. Status Match
          bool matchesStatus =
              selectedStatus == "All" || txn.status == selectedStatus;

          // 3. Payment Type Match (Assuming your model has 'type')
          bool matchesType =
              selectedPaymentType == "All" || txn.type == selectedPaymentType;

          // 4. Amount Range Match
          bool matchesAmount = true;
          if (selectedAmountRange == "Up to 500")
            matchesAmount = txn.amount <= 500;
          else if (selectedAmountRange == "500 - 2000")
            matchesAmount = txn.amount > 500 && txn.amount <= 2000;

          return matchesSearch && matchesStatus && matchesType && matchesAmount;
        }).toList();

    setState(() {
      _filteredTransactions = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: const Text("Transaction History"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _runFilter(),
              style: const TextStyle(color: textPrimary),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: "Search by name, phone or UPI ID",
                hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: textSecondary),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: accentOrange, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: borderColor),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(
                  "Status",
                  () => _showFilterBottomSheet(
                    "Status",
                    ["All", "Success", "Failed", "Processing"],
                    selectedStatus,
                    (val) {
                      selectedStatus = val;
                      _runFilter();
                    },
                  ),
                ),
                _buildFilterChip(
                  "Date",
                  () => _showFilterBottomSheet(
                    "Date",
                    ["All", "This Month", "Last 30 Days", "Last 90 Days"],
                    selectedDateRange,
                    (val) {
                      selectedDateRange = val;
                      _runFilter();
                    },
                  ),
                ),
                _buildFilterChip(
                  "Amount",
                  () => _showFilterBottomSheet(
                    "Amount",
                    ["All", "Up to 500", "500 - 2000"],
                    selectedAmountRange,
                    (val) {
                      selectedAmountRange = val;
                      _runFilter();
                    },
                  ),
                ),
                _buildFilterChip(
                  "Type",
                  () => _showFilterBottomSheet(
                    "Payment Type",
                    ["All", "Money Sent", "Money Received", "Refund"],
                    selectedPaymentType,
                    (val) {
                      selectedPaymentType = val;
                      _runFilter();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildMonthlySummary(),
                const SizedBox(height: 24),

                const Text(
                  "RECENT TRANSACTIONS",
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                _filteredTransactions.isEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off,
                              color: textSecondary.withOpacity(0.5),
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "No matching transactions",
                              style: TextStyle(color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                    : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredTransactions.length,
                      itemBuilder: (context, index) {
                        final txn = _filteredTransactions[index];
                        return _buildTransactionItem(txn);
                      },
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [secondaryDark, cardBg]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Total Spent in April",
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "₹12,450.00",
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.analytics_outlined,
                color: accentOrange,
                size: 30,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const LinearProgressIndicator(
              value: 0.7, // Simulated 70% of budget
              backgroundColor: borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(accentOrange),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: textSecondary,
            ),
          ],
        ),
        labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
        backgroundColor: cardBg,
        shape: StadiumBorder(
          side: BorderSide(color: borderColor.withOpacity(0.5)),
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }

  void _showFilterBottomSheet(
    String category,
    List<String> options,
    String currentSelection,
    Function(String) onApply,
  ) {
    tempSelection = currentSelection;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: secondaryDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Filter by $category",
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    children:
                        options.map((option) {
                          final bool isSelected = tempSelection == option;
                          return ChoiceChip(
                            label: Text(option),
                            selected: isSelected,
                            selectedColor: accentOrange.withOpacity(0.2),
                            backgroundColor: cardBg,
                            labelStyle: TextStyle(
                              color: isSelected ? accentOrange : textPrimary,
                            ),
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: isSelected ? accentOrange : borderColor,
                              ),
                            ),
                            onSelected: (bool selected) {
                              setModalState(() => tempSelection = option);
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            onApply("All");
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Clear All",
                            style: TextStyle(color: textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentOrange,
                          ),
                          onPressed: () {
                            onApply(tempSelection);
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Apply",
                            style: TextStyle(color: primaryDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTransactionItem(Transaction txn) {
    // 1. DETERMINE WHO TO DISPLAY
    // If I received money, show the Sender's name. If I sent money, show the Recipient's name.
    bool isReceived = txn.type == 'Money Received';
    int displayContactId =
        isReceived ? txn.senderContactId : txn.recipientContactId;
    String displayName = _contactsMap[displayContactId]?.name ?? "Unknown";
    String displayLetter =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : "?";

    bool isSuccess = txn.status == 'Success'; // Your logic here

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // 2. UNIFIED AVATAR
          CircleAvatar(
            radius: 22,
            backgroundColor: secondaryDark,
            child: Text(
              displayLetter,
              style: const TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 3. NAME AND TIMESTAMP
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(txn.timestamp),
                  style: const TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),

          // 4. AMOUNT AND STATUS
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment:
                MainAxisAlignment
                    .center, // Vertically center if no status is shown
            children: [
              Text(
                "${isReceived ? '+' : ''} ₹${txn.amount}",
                style: TextStyle(
                  color: isReceived ? Colors.greenAccent : textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              // Only show the status row if the transaction was SENT
              if (!isReceived) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSuccess ? Icons.check_circle : Icons.error,
                      size: 12,
                      color: isSuccess ? Colors.greenAccent : Colors.redAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSuccess ? "Success" : "Failed",
                      style: TextStyle(
                        color:
                            isSuccess ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
