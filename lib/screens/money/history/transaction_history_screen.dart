import 'package:flutter/material.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:fraudguard_pay/config/theme.dart';
import 'package:intl/intl.dart';

/// transaction_history_screen.dart
/// Transaction history screen with search and filtering capabilities.
/// Flows: Home/Money → Transaction History → {Filter by status/date/amount}
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with AutomaticKeepAliveClientMixin {
  List<Transaction> _allTransactions = [];
  List<Transaction> _filteredTransactions = [];
  final TextEditingController _searchController = TextEditingController();
  Map<int, Contact> _contactsMap = {};

  String selectedStatus = "All";
  String selectedDateRange = "All";
  String selectedAmountRange = "All";
  String selectedPaymentType = "All";
  String tempSelection = "";
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true; // Keeps state when tab switching

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when coming back to this screen
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final dbHelper = DatabaseHelper();
      final contacts = await dbHelper.getContacts();
      final transactions = await dbHelper.getTransactions();

      // Build map of localId -> Contact
      final Map<int, Contact> contactsMap = {};
      for (var c in contacts) {
        if (c.localId != null) {
          contactsMap[c.localId!] = c;
        }
      }

      if (mounted) {
        setState(() {
          _contactsMap = contactsMap;
          _allTransactions = transactions;
          _filteredTransactions = List.from(transactions);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _runFilter() {
    String keyword = _searchController.text.toLowerCase();

    List<Transaction> results =
        _allTransactions.where((txn) {
          // Determine display name based on transaction direction
          final bool isReceived = txn.isReceived;
          final int displayContactId =
              isReceived ? txn.senderContactId : txn.recipientContactId;

          final Contact? contact = _contactsMap[displayContactId];
          final String displayName =
              contact?.name ??
              (displayContactId > 0 ? "User $displayContactId" : "Unknown");
          final String displayVpa = contact?.vpa ?? "";

          // 1. Search Text Match
          bool matchesSearch =
              keyword.isEmpty ||
              displayName.toLowerCase().contains(keyword) ||
              displayVpa.toLowerCase().contains(keyword) ||
              txn.amount.toString().contains(keyword);

          // 2. Status Match
          bool matchesStatus = selectedStatus == "All";
          if (!matchesStatus) {
            switch (selectedStatus) {
              case "Success":
                matchesStatus = txn.isSuccess;
                break;
              case "Failed":
                matchesStatus = txn.isFailed;
                break;
              case "Pending":
                matchesStatus = txn.isPending;
                break;
              case "Blocked":
                matchesStatus = txn.isFraud;
                break;
              case "Flagged":
                matchesStatus = txn.isReview;
                break;
            }
          }

          // 3. Payment Type Match
          bool matchesType = selectedPaymentType == "All";
          if (!matchesType) {
            switch (selectedPaymentType) {
              case "Money Sent":
                matchesType = txn.isSent;
                break;
              case "Money Received":
                matchesType = txn.isReceived;
                break;
            }
          }

          // 4. Amount Range Match
          bool matchesAmount = true;
          if (selectedAmountRange == "Up to 500") {
            matchesAmount = txn.amount <= 500;
          } else if (selectedAmountRange == "500 - 2000") {
            matchesAmount = txn.amount > 500 && txn.amount <= 2000;
          } else if (selectedAmountRange == "2000 - 5000") {
            matchesAmount = txn.amount > 2000 && txn.amount <= 5000;
          } else if (selectedAmountRange == "Above 5000") {
            matchesAmount = txn.amount > 5000;
          }

          // 5. Date Range Match
          bool matchesDate = true;
          final now = DateTime.now();
          if (selectedDateRange == "This Month") {
            matchesDate =
                txn.timestamp.year == now.year &&
                txn.timestamp.month == now.month;
          } else if (selectedDateRange == "Last 30 Days") {
            matchesDate = txn.timestamp.isAfter(
              now.subtract(const Duration(days: 30)),
            );
          } else if (selectedDateRange == "Last 90 Days") {
            matchesDate = txn.timestamp.isAfter(
              now.subtract(const Duration(days: 90)),
            );
          }

          return matchesSearch &&
              matchesStatus &&
              matchesType &&
              matchesAmount &&
              matchesDate;
        }).toList();

    setState(() {
      _filteredTransactions = results;
    });
  }

  double _getTotalSpentThisMonth() {
    final now = DateTime.now();
    return _allTransactions
        .where(
          (txn) =>
              txn.isSent &&
              txn.isSuccess &&
              txn.timestamp.year == now.year &&
              txn.timestamp.month == now.month,
        )
        .fold(0.0, (sum, txn) => sum + txn.amount);
  }

  double _getMonthlyBudget() {
    return 20000.0; // Simulated budget
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final totalSpent = _getTotalSpentThisMonth();
    final budget = _getMonthlyBudget();
    final budgetPercentage = totalSpent / budget;

    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: const Text("Transaction History"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadData(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: accentOrange,
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: accentOrange),
                )
                : Column(
                  children: [
                    _buildSearchBar(),
                    _buildFilterChips(),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildMonthlySummary(totalSpent, budgetPercentage),
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
                              ? _buildEmptyState()
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
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => _runFilter(),
        style: const TextStyle(color: textPrimary),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: "Search by name, VPA or amount",
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip(
            "Status",
            () => _showFilterBottomSheet(
              "Status",
              ["All", "Success", "Failed", "Pending", "Blocked", "Flagged"],
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
              ["All", "Up to 500", "500 - 2000", "2000 - 5000", "Above 5000"],
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
              ["All", "Money Sent", "Money Received"],
              selectedPaymentType,
              (val) {
                selectedPaymentType = val;
                _runFilter();
              },
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

  Widget _buildMonthlySummary(double totalSpent, double budgetPercentage) {
    final currentMonth = DateFormat('MMMM').format(DateTime.now());

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
                children: [
                  Text(
                    "Total Spent in $currentMonth",
                    style: const TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹${totalSpent.toStringAsFixed(2)}",
                    style: const TextStyle(
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
            child: LinearProgressIndicator(
              value: budgetPercentage.clamp(0.0, 1.0),
              backgroundColor: borderColor,
              valueColor: const AlwaysStoppedAnimation<Color>(accentOrange),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${(budgetPercentage * 100).toStringAsFixed(0)}% of monthly budget",
            style: const TextStyle(color: textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
    );
  }

  Widget _buildTransactionItem(Transaction txn) {
    final bool isReceived = txn.isReceived;
    final int displayContactId =
        isReceived ? txn.senderContactId : txn.recipientContactId;

    final Contact? contact = _contactsMap[displayContactId];
    final String displayName =
        contact?.name ??
        (displayContactId > 0 ? "User $displayContactId" : "Unknown");
    final String displayLetter =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : "?";

    // Determine status display
    String statusText = "";
    Color statusColor = Colors.transparent;
    if (txn.isPending) {
      statusText = "Pending";
      statusColor = Colors.orange;
    } else if (txn.isFailed) {
      statusText = "Failed";
      statusColor = Colors.redAccent;
    } else if (txn.isFraud) {
      statusText = "Blocked";
      statusColor = Colors.redAccent;
    } else if (txn.isReview) {
      statusText = "Flagged";
      statusColor = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
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
                if (contact?.vpa != null && contact!.vpa.isNotEmpty)
                  Text(
                    contact.vpa,
                    style: const TextStyle(color: textSecondary, fontSize: 11),
                  ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(txn.timestamp),
                  style: const TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${isReceived ? '+' : '-'} ₹${txn.amount.toStringAsFixed(2)}",
                style: TextStyle(
                  color: isReceived ? Colors.greenAccent : textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (statusText.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
