import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseCategory {
  electricity,
  maintenance,
  cleaning,
  equipment,
  staffExpense,
  rent,
  marketing,
  supplies,
  other,
}

extension ExpenseCategoryX on ExpenseCategory {
  String get key => name;

  String get label => switch (this) {
        ExpenseCategory.electricity => 'Electricity',
        ExpenseCategory.maintenance => 'Maintenance',
        ExpenseCategory.cleaning => 'Cleaning',
        ExpenseCategory.equipment => 'Equipment',
        ExpenseCategory.staffExpense => 'Staff Expense',
        ExpenseCategory.rent => 'Rent',
        ExpenseCategory.marketing => 'Marketing',
        ExpenseCategory.supplies => 'Supplies',
        ExpenseCategory.other => 'Other',
      };

  static ExpenseCategory fromKey(String? k) =>
      ExpenseCategory.values.firstWhere(
        (c) => c.name == k,
        orElse: () => ExpenseCategory.other,
      );
}

class PosExpenseModel {
  final String id;
  final String arenaId;
  final String arenaName;
  final ExpenseCategory category;
  final double amount;
  final String description;
  final DateTime date;
  final String addedById;
  final String addedByName;
  final String? receiptRef;
  final String? shiftId;

  const PosExpenseModel({
    required this.id,
    required this.arenaId,
    required this.arenaName,
    required this.category,
    required this.amount,
    required this.description,
    required this.date,
    required this.addedById,
    required this.addedByName,
    this.receiptRef,
    this.shiftId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'arenaId': arenaId,
        'arenaName': arenaName,
        'category': category.key,
        'amount': amount,
        'description': description,
        'date': Timestamp.fromDate(date),
        'addedById': addedById,
        'addedByName': addedByName,
        if (receiptRef != null) 'receiptRef': receiptRef,
        if (shiftId != null) 'shiftId': shiftId,
      };

  factory PosExpenseModel.fromMap(Map<String, dynamic> m) => PosExpenseModel(
        id: m['id'] ?? '',
        arenaId: m['arenaId'] ?? '',
        arenaName: m['arenaName'] ?? '',
        category: ExpenseCategoryX.fromKey(m['category']),
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        description: m['description'] ?? '',
        date: m['date'] is Timestamp
            ? (m['date'] as Timestamp).toDate()
            : DateTime.now(),
        addedById: m['addedById'] ?? '',
        addedByName: m['addedByName'] ?? '',
        receiptRef: m['receiptRef'] as String?,
        shiftId: m['shiftId'] as String?,
      );
}
