import 'package:flutter/material.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:fraudguard_pay/screens/fraud/fraud_details_screen.dart';
import 'package:fraudguard_pay/widgets/theme.dart';

class FraudGuardSummaryScreen extends StatefulWidget {
  const FraudGuardSummaryScreen({super.key});

  @override
  State<FraudGuardSummaryScreen> createState() =>
      _FraudGuardSummaryScreenState();
}

class _FraudGuardSummaryScreenState extends State<FraudGuardSummaryScreen> {
  Map<int, Contact> _contactsMap = {};
  List<Transaction> _fraudTransactions = [];
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
      _fraudTransactions = fraudTransactions;
      _isLoading = false;
    });
  }

  int get _blockedCount {
    return _fraudTransactions
        .where((t) => t.fraudStatus == Transaction.FRAUD_FRAUD)
        .length;
  }

  int get _flaggedCount {
    return _fraudTransactions
        .where((t) => t.fraudStatus == Transaction.FRAUD_REVIEW)
        .length;
  }

  double get _totalAmountSaved {
    // Sum of all blocked transactions (potential fraud prevented)
    return _fraudTransactions
        .where((t) => t.fraudStatus == Transaction.FRAUD_FRAUD)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  @override
  Widget build(BuildContext context) {
    final blockedCount = _blockedCount;
    final flaggedCount = _flaggedCount;
    final amountSaved = _totalAmountSaved;

    // Prepare preview list (3 most recent)
    final sortedHistory = List.from(_fraudTransactions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final previewList = sortedHistory.take(3).toList();

    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: const Text("FraudGuard Shield"),
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
              : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSecurityHeader(),
                    const SizedBox(height: 24),

                    // Stats Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            "Flagged",
                            "$flaggedCount",
                            Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            "Blocked",
                            "$blockedCount",
                            Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStatCard(
                      "Amount Saved",
                      "₹${amountSaved.toStringAsFixed(2)}",
                      Colors.greenAccent,
                      isFullWidth: true,
                    ),

                    const SizedBox(height: 32),

                    // Fraud History Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "FRAUD ACTIVITY",
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            fontSize: 12,
                          ),
                        ),
                        if (_fraudTransactions.length > 3)
                          TextButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FraudDetailsScreen(),
                                ),
                              );
                              _loadData(); // Refresh on return
                            },
                            child: const Text(
                              "View All",
                              style: TextStyle(color: accentOrange),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Mini List
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child:
                          previewList.isEmpty
                              ? const Padding(
                                padding: EdgeInsets.all(30),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.shield_outlined,
                                        size: 48,
                                        color: textSecondary,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        "No threats detected",
                                        style: TextStyle(color: textSecondary),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "Your transactions are secure",
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: previewList.length,
                                separatorBuilder:
                                    (_, __) => const Divider(
                                      color: Colors.white10,
                                      height: 1,
                                    ),
                                itemBuilder:
                                    (context, index) =>
                                        _buildFraudTile(previewList[index]),
                              ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildFraudTile(Transaction fraud) {
    final bool isBlocked = fraud.fraudStatus == Transaction.FRAUD_FRAUD;
    final bool isReview = fraud.fraudStatus == Transaction.FRAUD_REVIEW;

    // Get the contact (recipient for sent fraud, sender for received fraud)
    final int displayContactId =
        fraud.isSent ? fraud.recipientContactId : fraud.senderContactId;

    final Contact? contact = _contactsMap[displayContactId];
    final String displayName =
        contact?.name ?? (displayContactId > 0 ? "Unknown User" : "You");
    final String displayVpa = contact?.vpa ?? "";

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            isBlocked
                ? Colors.red.withOpacity(0.1)
                : Colors.amber.withOpacity(0.1),
        child: Icon(
          isBlocked ? Icons.block_flipped : Icons.report_problem_outlined,
          color: isBlocked ? Colors.redAccent : Colors.amber,
          size: 20,
        ),
      ),
      title: Text(
        displayName,
        style: const TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (displayVpa.isNotEmpty)
            Text(
              displayVpa,
              style: const TextStyle(color: textSecondary, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            isBlocked
                ? "Critical Threat - Transaction Blocked"
                : "Flagged for AI Review - Manual verification needed",
            style: TextStyle(
              color:
                  isBlocked
                      ? Colors.redAccent.withOpacity(0.7)
                      : Colors.amber.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            "₹${fraud.amount.toStringAsFixed(2)}",
            style: const TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (fraud.riskScore != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    isBlocked
                        ? Colors.red.withOpacity(0.2)
                        : Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "Risk: ${(fraud.riskScore! * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                  color: isBlocked ? Colors.redAccent : Colors.amber,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _buildSecurityHeader() {
  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [secondaryDark, primaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.verified_user, size: 60, color: Colors.greenAccent),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Your account is protected",
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "FraudGuard AI actively monitors all transactions in real-time.",
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildStatCard(
  String label,
  String value,
  Color color, {
  bool isFullWidth = false,
}) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor),
    ),
    child: Column(
      crossAxisAlignment:
          isFullWidth ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
