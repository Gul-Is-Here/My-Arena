import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/pos_expense_model.dart';
import '../data/models/pos_product_model.dart';
import '../data/models/pos_shift_model.dart';
import '../data/models/pos_transaction_model.dart';

class PosService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _txns =>
      _db.collection('posTransactions');
  CollectionReference<Map<String, dynamic>> get _expenses =>
      _db.collection('posExpenses');
  CollectionReference<Map<String, dynamic>> get _shifts =>
      _db.collection('posShifts');
  CollectionReference<Map<String, dynamic>> _products(String arenaId) =>
      _db.collection('arenas').doc(arenaId).collection('posProducts');

  // ── Transactions ─────────────────────────────────────────────────────────
  // NOTE: Only filter by arenaId to avoid composite index requirement.
  // Date filtering and sorting are done client-side.

  Stream<List<PosTransactionModel>> transactionsStream(
    String arenaId, {
    int limit = 200,
    DateTime? from,
    DateTime? to,
  }) {
    return _txns
        .where('arenaId', isEqualTo: arenaId)
        .snapshots()
        .map((s) {
      var list = s.docs
          .map((d) => PosTransactionModel.fromMap(d.data()))
          .toList();
      if (from != null) list = list.where((t) => !t.createdAt.isBefore(from)).toList();
      if (to != null) list = list.where((t) => !t.createdAt.isAfter(to)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    });
  }

  Future<String> createTransaction(PosTransactionModel txn) async {
    final ref = _txns.doc();
    await ref.set({...txn.toMap(), 'id': ref.id});
    return ref.id;
  }

  // ── Expenses ──────────────────────────────────────────────────────────────
  // NOTE: Only filter by arenaId. Sort/date filter client-side.

  Stream<List<PosExpenseModel>> expensesStream(
    String arenaId, {
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) {
    return _expenses
        .where('arenaId', isEqualTo: arenaId)
        .snapshots()
        .map((s) {
      var list = s.docs
          .map((d) => PosExpenseModel.fromMap(d.data()))
          .toList();
      if (from != null) list = list.where((e) => !e.date.isBefore(from)).toList();
      if (to != null) list = list.where((e) => !e.date.isAfter(to)).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list.take(limit).toList();
    });
  }

  Future<String> addExpense(PosExpenseModel expense) async {
    final ref = _expenses.doc();
    await ref.set({...expense.toMap(), 'id': ref.id});
    return ref.id;
  }

  Future<void> deleteExpense(String expenseId) =>
      _expenses.doc(expenseId).delete();

  // ── Shifts ────────────────────────────────────────────────────────────────
  // NOTE: Only filter by arenaId. Sort/status filter client-side.

  Stream<PosShiftModel?> openShiftStream(String arenaId, String staffId) =>
      _shifts
          .where('arenaId', isEqualTo: arenaId)
          .snapshots()
          .map((s) {
        final open = s.docs
            .map((d) => PosShiftModel.fromMap(d.data()))
            .where((sh) => sh.status == ShiftStatus.open && sh.staffId == staffId)
            .toList();
        return open.isEmpty ? null : open.first;
      });

  Stream<List<PosShiftModel>> shiftsStream(String arenaId, {int limit = 30}) =>
      _shifts
          .where('arenaId', isEqualTo: arenaId)
          .snapshots()
          .map((s) {
        final list = s.docs
            .map((d) => PosShiftModel.fromMap(d.data()))
            .toList()
          ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
        return list.take(limit).toList();
      });

  Future<PosShiftModel> openShift(PosShiftModel shift) async {
    final ref = _shifts.doc();
    final model = PosShiftModel(
      id: ref.id,
      arenaId: shift.arenaId,
      arenaName: shift.arenaName,
      staffId: shift.staffId,
      staffName: shift.staffName,
      status: ShiftStatus.open,
      openedAt: shift.openedAt,
      openingCash: shift.openingCash,
    );
    await ref.set(model.toMap());
    return model;
  }

  Future<void> closeShift(String shiftId, double closingCash, String notes) =>
      _shifts.doc(shiftId).update({
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
        'closingCash': closingCash,
        'notes': notes,
      });

  Future<void> updateShiftSales(
    String shiftId, {
    double cashDelta = 0,
    double cardDelta = 0,
    double otherDelta = 0,
    double cashRefundDelta = 0,
    double expenseDelta = 0,
  }) =>
      _shifts.doc(shiftId).update({
        if (cashDelta != 0) 'cashSales': FieldValue.increment(cashDelta),
        if (cardDelta != 0) 'cardSales': FieldValue.increment(cardDelta),
        if (otherDelta != 0) 'otherSales': FieldValue.increment(otherDelta),
        if (cashRefundDelta != 0) 'cashRefunds': FieldValue.increment(cashRefundDelta),
        if (expenseDelta != 0) 'expenses': FieldValue.increment(expenseDelta),
      });

  // ── Products / Add-ons ────────────────────────────────────────────────────
  // NOTE: No compound query — filter/sort client-side.

  Stream<List<PosProductModel>> productsStream(String arenaId) =>
      _products(arenaId)
          .snapshots()
          .map((s) {
        final list = s.docs
            .map((d) => PosProductModel.fromMap(d.data()))
            .where((p) => p.isActive)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return list;
      });

  Future<String> upsertProduct(PosProductModel product) async {
    final ref = product.id.isEmpty
        ? _products(product.arenaId).doc()
        : _products(product.arenaId).doc(product.id);
    await ref.set({...product.toMap(), 'id': ref.id}, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> toggleProduct(String arenaId, String productId, bool active) =>
      _products(arenaId).doc(productId).update({'isActive': active});

  Future<void> deleteProduct(String arenaId, String productId) =>
      _products(arenaId).doc(productId).delete();

  // ── Aggregated stats — client-side calculation from streams ──────────────
  // NOTE: One-time fetch only by arenaId, date filtering done client-side.

  Future<Map<String, double>> todayStats(String arenaId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final txSnap = await _txns.where('arenaId', isEqualTo: arenaId).get();
    final expSnap = await _expenses.where('arenaId', isEqualTo: arenaId).get();

    double revenue = 0, paid = 0, remaining = 0, expenses = 0;

    for (final d in txSnap.docs) {
      final m = d.data();
      final ts = m['createdAt'];
      DateTime? dt;
      if (ts is Timestamp) dt = ts.toDate();
      if (dt == null || dt.isBefore(start) || !dt.isBefore(end)) continue;
      revenue += (m['totalAmount'] as num?)?.toDouble() ?? 0;
      paid += (m['amountPaid'] as num?)?.toDouble() ?? 0;
      remaining += (m['remainingAmount'] as num?)?.toDouble() ?? 0;
    }

    for (final d in expSnap.docs) {
      final m = d.data();
      final ts = m['date'];
      DateTime? dt;
      if (ts is Timestamp) dt = ts.toDate();
      if (dt == null || dt.isBefore(start) || !dt.isBefore(end)) continue;
      expenses += (m['amount'] as num?)?.toDouble() ?? 0;
    }

    return {
      'revenue': revenue,
      'paid': paid,
      'remaining': remaining,
      'expenses': expenses,
      'net': paid - expenses,
    };
  }
}
