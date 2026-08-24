import 'package:cloud_firestore/cloud_firestore.dart';

enum ShiftStatus { open, closed }

class PosShiftModel {
  final String id;
  final String arenaId;
  final String arenaName;
  final String staffId;
  final String staffName;
  final ShiftStatus status;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double openingCash;
  final double closingCash; // actual cash counted at close
  final double cashSales;
  final double cardSales;
  final double otherSales;
  final double cashRefunds;
  final double expenses;
  final double cashIn; // mid-shift cash added to drawer (not from sales)
  final String notes;

  const PosShiftModel({
    required this.id,
    required this.arenaId,
    required this.arenaName,
    required this.staffId,
    required this.staffName,
    required this.status,
    required this.openedAt,
    this.closedAt,
    required this.openingCash,
    this.closingCash = 0,
    this.cashSales = 0,
    this.cardSales = 0,
    this.otherSales = 0,
    this.cashRefunds = 0,
    this.expenses = 0,
    this.cashIn = 0,
    this.notes = '',
  });

  double get totalRevenue => cashSales + cardSales + otherSales;
  double get expectedCash => openingCash + cashIn + cashSales - cashRefunds - expenses;
  double get cashDifference => closingCash - expectedCash;
  double get netRevenue => totalRevenue - cashRefunds - expenses;

  Map<String, dynamic> toMap() => {
        'id': id,
        'arenaId': arenaId,
        'arenaName': arenaName,
        'staffId': staffId,
        'staffName': staffName,
        'status': status.name,
        'openedAt': Timestamp.fromDate(openedAt),
        if (closedAt != null) 'closedAt': Timestamp.fromDate(closedAt!),
        'openingCash': openingCash,
        'closingCash': closingCash,
        'cashSales': cashSales,
        'cardSales': cardSales,
        'otherSales': otherSales,
        'cashRefunds': cashRefunds,
        'expenses': expenses,
        if (cashIn != 0) 'cashIn': cashIn,
        if (notes.isNotEmpty) 'notes': notes,
      };

  factory PosShiftModel.fromMap(Map<String, dynamic> m) => PosShiftModel(
        id: m['id'] ?? '',
        arenaId: m['arenaId'] ?? '',
        arenaName: m['arenaName'] ?? '',
        staffId: m['staffId'] ?? '',
        staffName: m['staffName'] ?? '',
        status: m['status'] == 'closed' ? ShiftStatus.closed : ShiftStatus.open,
        openedAt: m['openedAt'] is Timestamp
            ? (m['openedAt'] as Timestamp).toDate()
            : DateTime.now(),
        closedAt: m['closedAt'] != null
            ? (m['closedAt'] as Timestamp).toDate()
            : null,
        openingCash: (m['openingCash'] as num?)?.toDouble() ?? 0,
        closingCash: (m['closingCash'] as num?)?.toDouble() ?? 0,
        cashSales: (m['cashSales'] as num?)?.toDouble() ?? 0,
        cardSales: (m['cardSales'] as num?)?.toDouble() ?? 0,
        otherSales: (m['otherSales'] as num?)?.toDouble() ?? 0,
        cashRefunds: (m['cashRefunds'] as num?)?.toDouble() ?? 0,
        expenses: (m['expenses'] as num?)?.toDouble() ?? 0,
        cashIn: (m['cashIn'] as num?)?.toDouble() ?? 0,
        notes: m['notes'] ?? '',
      );

  PosShiftModel copyWith({
    ShiftStatus? status,
    DateTime? closedAt,
    double? closingCash,
    double? cashSales,
    double? cardSales,
    double? otherSales,
    double? cashRefunds,
    double? expenses,
    double? cashIn,
    String? notes,
  }) =>
      PosShiftModel(
        id: id,
        arenaId: arenaId,
        arenaName: arenaName,
        staffId: staffId,
        staffName: staffName,
        status: status ?? this.status,
        openedAt: openedAt,
        closedAt: closedAt ?? this.closedAt,
        openingCash: openingCash,
        closingCash: closingCash ?? this.closingCash,
        cashSales: cashSales ?? this.cashSales,
        cardSales: cardSales ?? this.cardSales,
        otherSales: otherSales ?? this.otherSales,
        cashRefunds: cashRefunds ?? this.cashRefunds,
        expenses: expenses ?? this.expenses,
        cashIn: cashIn ?? this.cashIn,
        notes: notes ?? this.notes,
      );
}
