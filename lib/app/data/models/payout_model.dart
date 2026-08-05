import 'package:cloud_firestore/cloud_firestore.dart';

enum PayoutStatus { pending, paid, failed }

extension PayoutStatusX on PayoutStatus {
  String get value => name;
  String get label => switch (this) {
        PayoutStatus.pending => 'Pending',
        PayoutStatus.paid => 'Paid',
        PayoutStatus.failed => 'Failed',
      };

  static PayoutStatus fromString(String v) =>
      PayoutStatus.values.firstWhere((e) => e.name == v,
          orElse: () => PayoutStatus.pending);
}

class PayoutModel {
  final String id;
  final String ownerId;
  final String ownerName;
  final double amount;
  final List<String> bookingRefs;
  final String paidById;
  final String paidByName;
  final DateTime? paidAt;
  final String paymentMethod;
  final String notes;
  final PayoutStatus status;
  final DateTime createdAt;

  const PayoutModel({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.amount,
    required this.bookingRefs,
    required this.paidById,
    required this.paidByName,
    this.paidAt,
    this.paymentMethod = '',
    this.notes = '',
    this.status = PayoutStatus.pending,
    required this.createdAt,
  });

  factory PayoutModel.fromMap(Map<String, dynamic> m, String id) => PayoutModel(
        id: id,
        ownerId: m['ownerId'] ?? '',
        ownerName: m['ownerName'] ?? '',
        amount: (m['amount'] ?? 0).toDouble(),
        bookingRefs: List<String>.from(m['bookingRefs'] ?? []),
        paidById: m['paidById'] ?? '',
        paidByName: m['paidByName'] ?? '',
        paidAt: m['paidAt'] != null ? (m['paidAt'] as Timestamp).toDate() : null,
        paymentMethod: m['paymentMethod'] ?? '',
        notes: m['notes'] ?? '',
        status: PayoutStatusX.fromString(m['status'] ?? 'pending'),
        createdAt: m['createdAt'] != null
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'ownerName': ownerName,
        'amount': amount,
        'bookingRefs': bookingRefs,
        'paidById': paidById,
        'paidByName': paidByName,
        if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
        'paymentMethod': paymentMethod,
        'notes': notes,
        'status': status.value,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// Per-owner finance summary computed client-side from bookings.
class OwnerFinanceSummary {
  final String ownerId;
  final String ownerName;
  final double totalEarned;
  final double totalPaid;
  final double totalPending;
  final DateTime? lastPayoutAt;
  final int bookingCount;

  const OwnerFinanceSummary({
    required this.ownerId,
    required this.ownerName,
    required this.totalEarned,
    required this.totalPaid,
    required this.totalPending,
    this.lastPayoutAt,
    required this.bookingCount,
  });
}
