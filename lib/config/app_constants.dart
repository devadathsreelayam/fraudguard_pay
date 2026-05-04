// ============================================================================
// APP CONSTANTS
// Global constants for the application (URLs, timeouts, default values, etc.)
// ============================================================================

class AppConstants {
  // Payment timeouts
  static const Duration paymentTimeout = Duration(seconds: 30);
  static const Duration pinEntryTimeout = Duration(minutes: 5);

  // Fraud detection thresholds (for future AI inference)
  static const double highRiskThreshold = 0.8;
  static const double mediumRiskThreshold = 0.5;

  // API endpoints (for future backend integration)
  static const String fraudDetectionEndpoint = '/api/fraud/detect';
  static const String transactionEndpoint = '/api/transactions';

  // Validation rules
  static const int minUpiLength = 1;
  static const int maxUpiLength = 60;
  static const int pinLength = 4;
  static const double minTransactionAmount = 1.0;
  static const double maxTransactionAmount = 100000.0;
}
