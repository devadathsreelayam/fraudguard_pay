import 'package:flutter/material.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/app_state_model.dart';
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

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final dbHelper = DatabaseHelper();
    final contacts = await dbHelper.getContacts();
    setState(() {
      _contactsMap = {for (var c in contacts) c.id!: c};
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Data Logic: Simple counts for the stats grid
    final blockedCount =
        fraudHistory.where((t) => t.status.toLowerCase() == 'blocked').length;
    final flaggedCount =
        fraudHistory.where((t) => t.status.toLowerCase() == 'flagged').length;

    // 2. Prepare the Preview List (Sorted by most recent)
    final sortedHistory = List.from(fraudHistory)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final previewList = sortedHistory.take(3).toList();

    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: const Text("FraudGuard Shield"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
              "₹1,42,000",
              Colors.greenAccent,
              isFullWidth: true,
            ),

            const SizedBox(height: 32),

            // UNIFIED FRAUD HISTORY SECTION
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
                if (fraudHistory.length > 3)
                  TextButton(
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FraudDetailsScreen(),
                          ),
                        ),
                    child: const Text(
                      "View All",
                      style: TextStyle(color: accentOrange),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // The Mini List
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
                          child: Text(
                            "No threats detected",
                            style: TextStyle(color: textSecondary),
                          ),
                        ),
                      )
                      : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: previewList.length,
                        separatorBuilder:
                            (_, __) =>
                                const Divider(color: Colors.white10, height: 1),
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

  // A single helper for the list items
  Widget _buildFraudTile(Transaction fraud) {
    bool isBlocked = fraud.status.toLowerCase() == 'blocked';
    String displayName =
        _contactsMap[fraud.recipientContactId]?.name ?? "Unknown";

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            isBlocked
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.amber.withValues(alpha: 0.1),
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
      ),
      subtitle: Text(
        isBlocked ? "Critical Threat Blocked" : "Flagged for AI Review",
        style: TextStyle(
          color:
              isBlocked
                  ? Colors.redAccent.withValues(alpha: 0.3)
                  : Colors.amber.withValues(alpha: 0.3),
          fontSize: 11,
        ),
      ),
      trailing: Text(
        "₹${fraud.amount}",
        style: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
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
      border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
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
                "Your account is safe",
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "FraudGuard AI is actively monitoring all transactions.",
                style: TextStyle(color: textSecondary, fontSize: 13),
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
