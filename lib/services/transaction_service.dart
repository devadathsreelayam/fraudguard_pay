import 'package:fraudguard_pay/models/transaction_model.dart';
import 'package:fraudguard_pay/models/app_state_model.dart';

// ============================================================================
// TRANSACTION SERVICE
// Provides business logic for transaction management.
// ============================================================================

class TransactionService {
  static final TransactionService _instance = TransactionService._internal();

  factory TransactionService() {
    return _instance;
  }

  TransactionService._internal();

  /// Get all transactions
  List<Transaction> getAllTransactions() {
    return transactionHistory;
  }

  /// Get transactions sorted by most recent first
  List<Transaction> getRecentTransactions({int limit = 10}) {
    final sorted = List<Transaction>.from(transactionHistory);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(limit).toList();
  }

  /// Get transactions for a specific contact
  List<Transaction> getContactTransactions(String contactName) {
    return transactionHistory
        .where(
          (txn) =>
              txn.recipientContactId == contactName ||
              txn.senderContactId == contactName,
        )
        .toList();
  }

  /// Get transactions by status
  List<Transaction> getTransactionsByStatus(String status) {
    return transactionHistory
        .where((txn) => txn.status.toLowerCase() == status.toLowerCase())
        .toList();
  }

  /// Get transactions within a date range
  List<Transaction> getTransactionsByDateRange(DateTime start, DateTime end) {
    return transactionHistory
        .where(
          (txn) => txn.timestamp.isAfter(start) && txn.timestamp.isBefore(end),
        )
        .toList();
  }

  /// Calculate total amount sent
  double getTotalSent() {
    return transactionHistory
        .where((txn) => txn.senderContactId == "me" && txn.status == "Success")
        .fold(0.0, (sum, txn) => sum + txn.amount);
  }

  /// Calculate total amount received
  double getTotalReceived() {
    return transactionHistory
        .where(
          (txn) => txn.recipientContactId == "me" && txn.status == "Success",
        )
        .fold(0.0, (sum, txn) => sum + txn.amount);
  }

  /// Add a new transaction
  void addTransaction(Transaction transaction) {
    transactionHistory.add(transaction);
  }

  /// Update a transaction
  void updateTransaction(String id, Transaction updatedTransaction) {
    final index = transactionHistory.indexWhere((txn) => txn.id == id);
    if (index != -1) {
      transactionHistory[index] = updatedTransaction;
    }
  }

  /// Delete a transaction
  void deleteTransaction(String id) {
    transactionHistory.removeWhere((txn) => txn.id == id);
  }
}
