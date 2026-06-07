import 'package:flutter/material.dart';

class Contact {
  final int? localId; // SQLite local PK
  final String name; // display name
  final String vpa; // the only real identifier
  final String phone;
  final String? avatar;
  final bool isVerified; // came back from Django resolve endpoint
  final bool isMerchant; // merchant vs customer
  final String? djangoId; // customer_id or merchant_id if resolved
  final DateTime? lastPaidAt; // for sorting recent contacts

  Contact({
    this.localId,
    required this.name,
    required this.vpa,
    required this.phone,
    this.avatar,
    this.isVerified = false,
    this.isMerchant = true,
    this.djangoId,
    this.lastPaidAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'local_id': localId,
      'name': name,
      'vpa': vpa,
      'phone': phone,
      'avatar': avatar,
      'is_verified': isVerified ? 1 : 0,
      'is_merchant': isMerchant ? 1 : 0,
      'django_id': djangoId,
      'last_paid_at': lastPaidAt?.toIso8601String(),
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      localId: map['local_id'],
      name: map['name'],
      vpa: map['vpa'],
      phone: map['phone'],
      avatar: map['avatar'],
      isVerified: map['is_verified'] == 1,
      isMerchant: map['is_merchant'] == 1,
      djangoId: map['django_id'],
      lastPaidAt:
          map['last_paid_at'] != null
              ? DateTime.parse(map['last_paid_at'])
              : null,
    );
  }

  Contact copyWith({
    int? localId,
    String? name,
    String? vpa,
    String? phone,
    String? avatar,
    bool? isVerified,
    bool? isMerchant,
    String? djangoId,
    DateTime? lastPaidAt,
  }) {
    return Contact(
      localId: localId ?? this.localId,
      name: name ?? this.name,
      vpa: vpa ?? this.vpa,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      isVerified: isVerified ?? this.isVerified,
      isMerchant: isMerchant ?? this.isMerchant,
      djangoId: djangoId ?? this.djangoId,
      lastPaidAt: lastPaidAt ?? this.lastPaidAt,
    );
  }

  String get displayType => isMerchant ? 'Business' : 'Customer';
  String get displayBadge =>
      isVerified ? '✓ Verified' : (isMerchant ? '⚠️ Unverified' : '');
  Color get badgeColor => isVerified ? Colors.green : Colors.orange;
}
