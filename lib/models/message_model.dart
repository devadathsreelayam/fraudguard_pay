class Message {
  final String id;
  final int senderContactId;
  final int recipientContactId;
  final String text;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.senderContactId,
    required this.recipientContactId,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_contact_id': senderContactId,
      'recipient_contact_id': recipientContactId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      senderContactId: map['sender_contact_id'],
      recipientContactId: map['recipient_contact_id'],
      text: map['text'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
