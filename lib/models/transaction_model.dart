class Transaction {
  final String id;
  final DateTime timestamp;
  final int senderContactId; // contact.id of sender (e.g., 0 for "me")
  final int recipientContactId; // contact.id of recipient
  final double amount;
  final String type;
  final String status;
  final String? note;
  final bool isFraud;
  final String? riskFactors;
  final String? serverTransactionId;

  Transaction({
    required this.id,
    required this.timestamp,
    required this.senderContactId,
    required this.recipientContactId,
    required this.amount,
    this.type = "Money Sent",
    this.status = "Success",
    this.note,
    this.isFraud = false,
    this.riskFactors,
    this.serverTransactionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'sender_contact_id': senderContactId,
      'recipient_contact_id': recipientContactId,
      'amount': amount,
      'type': type,
      'status': status,
      'note': note,
      'is_fraud': isFraud ? 1 : 0,
      'risk_factors': riskFactors,
      'server_transaction_id': serverTransactionId,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      timestamp: DateTime.parse(map['timestamp']),
      senderContactId: map['sender_contact_id'],
      recipientContactId: map['recipient_contact_id'],
      amount: map['amount'],
      type: map['type'],
      status: map['status'],
      note: map['note'],
      isFraud: map['is_fraud'] == 1,
      riskFactors: map['risk_factors'],
      serverTransactionId: map['server_transaction_id'],
    );
  }
}
