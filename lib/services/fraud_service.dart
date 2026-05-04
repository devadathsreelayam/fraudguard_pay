import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:fraudguard_pay/models/app_state_model.dart';

// ============================================================================
// FRAUD SERVICE
// Provides business logic for fraud detection and management.
// TODO: Integrate with AI inference server for real-time fraud detection.
// ============================================================================

class FraudService {
  static final FraudService _instance = FraudService._internal();

  factory FraudService() {
    return _instance;
  }

  FraudService._internal();

  /// Get all fraud transactions
  List<Transaction> getAllTransactions() {
    return fraudHistory;
  }

  /// Get flagged fraud transactions
  List<Transaction> getFlaggedTransactions() {
    return fraudHistory.where((fraud) => fraud.status == "Flagged").toList();
  }

  /// Get blocked fraud transactions
  List<Transaction> getBlockedTransactions() {
    return fraudHistory.where((fraud) => fraud.status == "Blocked").toList();
  }

  /// Get fraud transactions for a specific recipient
  // List<Transaction> getFraudByRecipient(String recipient) {

  //   return fraudHistory
  //       .where(
  //         (fraud) => fraud.recipientContactId.toLowerCase().contains(
  //           recipient.toLowerCase(),
  //         ),
  //       )
  //       .toList();
  // }

  /// Add a new fraud transaction
  void addTransaction(Transaction transaction) {
    fraudHistory.add(transaction);
  }

  /// Get fraud transaction count by status
  Map<String, int> getFraudCountByStatus() {
    final Map<String, int> counts = {};
    for (var fraud in fraudHistory) {
      counts[fraud.status] = (counts[fraud.status] ?? 0) + 1;
    }
    return counts;
  }

  /// Calculate total amount flagged
  double getTotalFlaggedAmount() {
    return fraudHistory
        .where((fraud) => fraud.status == "Flagged")
        .fold(0.0, (sum, fraud) => sum + fraud.amount);
  }

  /// Calculate total amount blocked
  double getTotalBlockedAmount() {
    return fraudHistory
        .where((fraud) => fraud.status == "Blocked")
        .fold(0.0, (sum, fraud) => sum + fraud.amount);
  }
}
