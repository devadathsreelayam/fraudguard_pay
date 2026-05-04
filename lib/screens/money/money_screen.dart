import 'package:flutter/material.dart';
import 'package:fraudguard_pay/config/theme.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:fraudguard_pay/screens/payment/upi_pin_screen.dart';
import 'package:fraudguard_pay/screens/money/history/transaction_history_screen.dart';
import 'package:intl/intl.dart';

/// Money/Wallet screen showing spending overview and recent transactions.
/// Flows: Home → Money Screen → {Check Balance, Transaction History}
class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  Map<int, Contact> _contactsMap = {};
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final dbHelper = DatabaseHelper();
    final contacts = await dbHelper.getContacts();
    final transactions = await dbHelper.getTransactions();

    setState(() {
      _contactsMap = {for (var c in contacts) c.id!: c};
      _transactions = transactions;
      _isLoading = false;
    });
  }

  Future<void> _refreshData() async {
    await _loadContacts();
    setState(() {}); // Force UI rebuild to show new transactions
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: const Text(
          "Money",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSpendingCard(context),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle("Recent Transactions"),
                TextButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TransactionHistoryScreen(),
                      ),
                    );
                    _refreshData(); // Add this
                  },
                  child: const Text(
                    "See All",
                    style: TextStyle(color: accentOrange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildMiniHistory(),
            const SizedBox(height: 32),
            _buildSectionTitle("Credit & Loans"),
            const SizedBox(height: 16),
            _buildCreditScoreTile(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: secondaryDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Spend Today",
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            "₹1,420.00",
            style: TextStyle(
              color: textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final dummyContact = Contact(
                id: null, // Use null, not -1
                name: "Bank Verification",
                vpa: "bank@upi",
                phone: "986532875",
              );
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => UpiPinScreen(
                        contact: dummyContact,
                        amount: "0",
                        note: "",
                        isCheckingBalance: true,
                      ),
                ),
              );
              _refreshData();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  "Check Account Balance",
                  style: TextStyle(
                    color: accentOrange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(Icons.chevron_right, color: accentOrange, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniHistory() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: accentOrange),
      );
    }

    // Get the 4 most recent transactions from _transactions
    final List<Transaction> recentTransactions =
        _transactions.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Take only the top 4
    final displayList = recentTransactions.take(4).toList();

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child:
          displayList.isEmpty
              ? const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    "No recent activity",
                    style: TextStyle(color: textSecondary),
                  ),
                ),
              )
              : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayList.length,
                separatorBuilder:
                    (context, index) =>
                        const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  final txn = displayList[index];

                  // Map the Transaction object to the UI
                  bool isReceived = txn.type == "Money Received";
                  int displayContactId =
                      isReceived ? txn.senderContactId : txn.recipientContactId;
                  String displayName =
                      _contactsMap[displayContactId]?.name ?? "Unknown";

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: secondaryDark,
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : "?",
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      displayName,
                      style: const TextStyle(color: textPrimary, fontSize: 15),
                    ),
                    subtitle: Text(
                      DateFormat('dd MMM, hh:mm a').format(txn.timestamp),
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${isReceived ? '+' : ''}₹${txn.amount}",
                          style: TextStyle(
                            color:
                                isReceived ? Colors.greenAccent : textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (txn.status == "Failed")
                          const Text(
                            "Failed",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildCreditScoreTile() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF1E3A6F),
          child: Icon(Icons.speed, color: accentOrange),
        ),
        title: const Text(
          "Check Credit Score",
          style: TextStyle(color: textPrimary),
        ),
        subtitle: const Text(
          "CIBIL • Updated 2 days ago",
          style: TextStyle(color: textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: textSecondary),
        onTap: () {},
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
