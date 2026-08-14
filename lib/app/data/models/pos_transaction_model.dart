import 'package:cloud_firestore/cloud_firestore.dart';

enum PosPaymentMethod { cash, card, jazzcash, easypaisa, bankTransfer, other }

extension PosPaymentMethodX on PosPaymentMethod {
  String get key => switch (this) {
        PosPaymentMethod.cash => 'cash',
        PosPaymentMethod.card => 'card',
        PosPaymentMethod.jazzcash => 'jazzcash',
        PosPaymentMethod.easypaisa => 'easypaisa',
        PosPaymentMethod.bankTransfer => 'bank_transfer',
        PosPaymentMethod.other => 'other',
      };

  String get label => switch (this) {
        PosPaymentMethod.cash => 'Cash',
        PosPaymentMethod.card => 'Card',
        PosPaymentMethod.jazzcash => 'JazzCash',
        PosPaymentMethod.easypaisa => 'Easypaisa',
        PosPaymentMethod.bankTransfer => 'Bank Transfer',
        PosPaymentMethod.other => 'Other',
      };

  static PosPaymentMethod fromKey(String? k) =>
      PosPaymentMethod.values.firstWhere(
        (m) => m.key == k,
        orElse: () => PosPaymentMethod.cash,
      );
}

enum PosTransactionType { booking, addOn, expense, refund, adjustment, checkout }

extension PosTransactionTypeX on PosTransactionType {
  String get key => name;
  static PosTransactionType fromKey(String? k) =>
      PosTransactionType.values.firstWhere(
        (t) => t.name == k,
        orElse: () => PosTransactionType.booking,
      );
}

class PosTransactionModel {
  final String id;
  final String arenaId;
  final String arenaName;
  final String? bookingId;
  final String? courtId;
  final String? courtName;
  final String? customerId;
  final String customerName;
  final PosTransactionType type;
  final PosPaymentMethod paymentMethod;
  final double totalAmount;
  final double amountPaid;
  final double remainingAmount;
  final double discount;
  final String? refNo; // bank transfer ref / card auth code
  final String processedById;
  final String processedByName;
  final String processedByRole;
  final DateTime createdAt;
  final String? shiftId;
  final String notes;

  const PosTransactionModel({
    required this.id,
    required this.arenaId,
    required this.arenaName,
    this.bookingId,
    this.courtId,
    this.courtName,
    this.customerId,
    this.customerName = '',
    required this.type,
    required this.paymentMethod,
    required this.totalAmount,
    required this.amountPaid,
    this.remainingAmount = 0,
    this.discount = 0,
    this.refNo,
    required this.processedById,
    required this.processedByName,
    this.processedByRole = 'owner',
    required this.createdAt,
    this.shiftId,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'arenaId': arenaId,
        'arenaName': arenaName,
        if (bookingId != null) 'bookingId': bookingId,
        if (courtId != null) 'courtId': courtId,
        if (courtName != null) 'courtName': courtName,
        if (customerId != null) 'customerId': customerId,
        'customerName': customerName,
        'type': type.key,
        'paymentMethod': paymentMethod.key,
        'totalAmount': totalAmount,
        'amountPaid': amountPaid,
        'remainingAmount': remainingAmount,
        'discount': discount,
        if (refNo != null) 'refNo': refNo,
        'processedById': processedById,
        'processedByName': processedByName,
        'processedByRole': processedByRole,
        'createdAt': Timestamp.fromDate(createdAt),
        if (shiftId != null) 'shiftId': shiftId,
        if (notes.isNotEmpty) 'notes': notes,
      };

  factory PosTransactionModel.fromMap(Map<String, dynamic> m) =>
      PosTransactionModel(
        id: m['id'] ?? '',
        arenaId: m['arenaId'] ?? '',
        arenaName: m['arenaName'] ?? '',
        bookingId: m['bookingId'] as String?,
        courtId: m['courtId'] as String?,
        courtName: m['courtName'] as String?,
        customerId: m['customerId'] as String?,
        customerName: m['customerName'] ?? '',
        type: PosTransactionTypeX.fromKey(m['type']),
        paymentMethod: PosPaymentMethodX.fromKey(m['paymentMethod']),
        totalAmount: (m['totalAmount'] as num?)?.toDouble() ?? 0,
        amountPaid: (m['amountPaid'] as num?)?.toDouble() ?? 0,
        remainingAmount: (m['remainingAmount'] as num?)?.toDouble() ?? 0,
        discount: (m['discount'] as num?)?.toDouble() ?? 0,
        refNo: m['refNo'] as String?,
        processedById: m['processedById'] ?? '',
        processedByName: m['processedByName'] ?? '',
        processedByRole: m['processedByRole'] ?? 'owner',
        createdAt: m['createdAt'] is Timestamp
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        shiftId: m['shiftId'] as String?,
        notes: m['notes'] ?? '',
      );
}
