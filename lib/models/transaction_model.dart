import 'package:flutter/material.dart';

class Transaction {
  // Recipient type constants
  static const String RECIPIENT_TYPE_CUSTOMER = 'CUSTOMER';
  static const String RECIPIENT_TYPE_MERCHANT = 'MERCHANT';

  // Transaction type constants
  static const String TRANSACTION_TYPE_P2P = 'P2P';
  static const String TRANSACTION_TYPE_P2M = 'P2M';

  // Status constants
  static const String STATUS_PENDING = 'PENDING';
  static const String STATUS_SUCCESS = 'SUCCESS';
  static const String STATUS_CANCELLED = 'CANCELLED';
  static const String STATUS_FAILED = 'FAILED';

  // Fraud status constants
  static const String FRAUD_LEGIT = 'LEGIT';
  static const String FRAUD_REVIEW = 'REVIEW';
  static const String FRAUD_FRAUD = 'FRAUD';

  // Sync status constants
  static const String SYNC_SYNCED = 'synced';
  static const String SYNC_PENDING = 'pending';

  final String id; // Local ID (UUID)
  final DateTime timestamp;
  final int senderContactId; // 0 = "me"
  final int recipientContactId;
  final double amount;
  final String transactionType; // "P2P" or "P2M"
  final String recipientType; // "CUSTOMER" or "MERCHANT"
  final String status; // "PENDING", "SUCCESS", "CANCELLED", "FAILED"
  final String fraudStatus; // "LEGIT", "REVIEW", "FRAUD"
  final String? note;
  final double? riskScore;
  final String userLocation;
  final String networkType;
  final String syncStatus; // "synced", "pending"

  Transaction({
    required this.id,
    required this.timestamp,
    required this.senderContactId,
    required this.recipientContactId,
    required this.amount,
    required this.transactionType,
    required this.recipientType,
    required this.status,
    required this.fraudStatus,
    this.note,
    this.riskScore,
    this.userLocation = '',
    this.networkType = '4G',
    this.syncStatus = SYNC_PENDING,
  });

  // Computed properties for UI
  bool get isSent => senderContactId == 0;
  bool get isReceived => senderContactId != 0;
  bool get isFraud => fraudStatus == FRAUD_FRAUD;
  bool get isReview => fraudStatus == FRAUD_REVIEW;
  bool get isLegit => fraudStatus == FRAUD_LEGIT;
  bool get isSuccess => status == STATUS_SUCCESS;
  bool get isFailed => status == STATUS_FAILED;
  bool get isCancelled => status == STATUS_CANCELLED;
  bool get isPending => status == STATUS_PENDING;
  bool get isP2P => transactionType == TRANSACTION_TYPE_P2P;
  bool get isP2M => transactionType == TRANSACTION_TYPE_P2M;
  bool get isSynced => syncStatus == SYNC_SYNCED;
  bool get needsSync => syncStatus == SYNC_PENDING;

  // Display text for UI
  String get displayType {
    if (isSent) {
      return "Money Sent";
    } else {
      return "Money Received";
    }
  }

  String get displayStatus {
    if (isPending) return "Pending";
    if (isSuccess) return "Success";
    if (isFailed) return "Failed";
    if (isCancelled) return "Cancelled";
    return status;
  }

  Color get statusColor {
    if (isSuccess) return Colors.green;
    if (isFailed || isCancelled) return Colors.red;
    if (isPending) return Colors.orange;
    return Colors.grey;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'sender_contact_id': senderContactId,
      'recipient_contact_id': recipientContactId,
      'amount': amount,
      'transaction_type': transactionType,
      'recipient_type': recipientType,
      'status': status,
      'fraud_status': fraudStatus,
      'note': note,
      'risk_score': riskScore,
      'user_location': userLocation,
      'network_type': networkType,
      'sync_status': syncStatus,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      timestamp: DateTime.parse(map['timestamp']),
      senderContactId: map['sender_contact_id'],
      recipientContactId: map['recipient_contact_id'],
      amount: map['amount'].toDouble(),
      transactionType: map['transaction_type'] ?? TRANSACTION_TYPE_P2M,
      recipientType: map['recipient_type'] ?? RECIPIENT_TYPE_MERCHANT,
      status: map['status'] ?? STATUS_PENDING,
      fraudStatus: map['fraud_status'] ?? FRAUD_LEGIT,
      note: map['note'],
      riskScore: map['risk_score']?.toDouble(),
      userLocation: map['user_location'] ?? '',
      networkType: map['network_type'] ?? '4G',
      syncStatus: map['sync_status'] ?? SYNC_PENDING,
    );
  }

  Transaction copyWith({
    String? id,
    DateTime? timestamp,
    int? senderContactId,
    int? recipientContactId,
    double? amount,
    String? transactionType,
    String? recipientType,
    String? status,
    String? fraudStatus,
    String? note,
    double? riskScore,
    String? userLocation,
    String? networkType,
    String? syncStatus,
  }) {
    return Transaction(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      senderContactId: senderContactId ?? this.senderContactId,
      recipientContactId: recipientContactId ?? this.recipientContactId,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      recipientType: recipientType ?? this.recipientType,
      status: status ?? this.status,
      fraudStatus: fraudStatus ?? this.fraudStatus,
      note: note ?? this.note,
      riskScore: riskScore ?? this.riskScore,
      userLocation: userLocation ?? this.userLocation,
      networkType: networkType ?? this.networkType,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
