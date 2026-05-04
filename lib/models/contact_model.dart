import 'transaction_model.dart';

class Contact {
  final int? id;
  final String name;
  final String vpa;
  final String phone;
  final String? avatar;

  Contact({
    this.id,
    required this.name,
    required this.vpa,
    required this.phone,
    this.avatar,
  });

  List<Transaction> getHistory(List<Transaction> allTransactions) {
    return allTransactions
        .where(
          (txn) =>
              txn.recipientContactId == name || txn.senderContactId == name,
        )
        .toList();
  }

  Transaction? lastTransaction(
    List<Transaction> allTransactions, {
    int myContactId = 0,
  }) {
    var history =
        allTransactions
            .where(
              (txn) =>
                  (txn.senderContactId == id &&
                      txn.recipientContactId == myContactId) ||
                  (txn.senderContactId == myContactId &&
                      txn.recipientContactId == id),
            )
            .toList();
    if (history.isEmpty) return null;
    history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return history.first;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'vpa': vpa,
      'phone': phone,
      'avatar': avatar,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'],
      name: map['name'],
      vpa: map['vpa'],
      phone: map['phone'],
      avatar: map['avatar'],
    );
  }
}
