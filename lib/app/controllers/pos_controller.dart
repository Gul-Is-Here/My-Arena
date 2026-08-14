import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../data/models/arena_model.dart';
import '../data/models/booking_model.dart';
import '../data/models/pos_expense_model.dart';
import '../data/models/pos_product_model.dart';
import '../data/models/pos_shift_model.dart';
import '../data/models/pos_transaction_model.dart';
import '../services/pos_service.dart';
import 'auth_controller.dart';
import 'owner_booking_controller.dart';
import 'owner_controller.dart';

class PosController extends GetxController {
  static PosController get to => Get.find();

  final PosService _service = PosService();

  // ── Selected arena (POS context) ──────────────────────────────────────
  final Rx<ArenaModel?> selectedArena = Rx(null);

  // ── Reactive lists ────────────────────────────────────────────────────
  final RxList<PosTransactionModel> transactions = <PosTransactionModel>[].obs;
  final RxList<PosExpenseModel> expenses = <PosExpenseModel>[].obs;
  final RxList<PosProductModel> products = <PosProductModel>[].obs;
  final RxList<PosShiftModel> shifts = <PosShiftModel>[].obs;
  final Rx<PosShiftModel?> openShift = Rx(null);

  // ── Dashboard stats ───────────────────────────────────────────────────
  final RxDouble todayRevenue = 0.0.obs;
  final RxDouble todayPaid = 0.0.obs;
  final RxDouble todayRemaining = 0.0.obs;
  final RxDouble todayExpenses = 0.0.obs;
  final RxDouble todayNet = 0.0.obs;

  // ── Loading ───────────────────────────────────────────────────────────
  final RxBool isLoading = false.obs;
  final RxBool statsLoading = false.obs;

  // ── Streams ───────────────────────────────────────────────────────────
  StreamSubscription? _txnSub;
  StreamSubscription? _expSub;
  StreamSubscription? _productSub;
  StreamSubscription? _shiftSub;
  StreamSubscription? _openShiftSub;

  String get _uid => AuthController.to.currentUser.value?.uid ?? '';
  String get _userName => AuthController.to.currentUser.value?.name ?? '';

  @override
  void onInit() {
    super.onInit();
    ever(OwnerController.to.myArenas, (arenas) {
      final current = selectedArena.value;
      if (current == null && arenas.isNotEmpty) {
        // First time: select arena and start all streams
        selectArena(arenas.first);
      } else if (current != null) {
        // Courts stream updated — keep selectedArena in sync so courts tab rebuilds
        final updated = arenas.firstWhereOrNull((a) => a.id == current.id);
        if (updated != null) selectedArena.value = updated;
      }
    });
    final arenas = OwnerController.to.myArenas;
    if (arenas.isNotEmpty) selectArena(arenas.first);
  }

  void selectArena(ArenaModel arena) {
    selectedArena.value = arena;
    _cancelSubs();
    _listenTransactions(arena.id);
    _listenExpenses(arena.id);
    _listenProducts(arena.id);
    _listenShifts(arena.id);
    _listenOpenShift(arena.id);
    refreshStats();
  }

  void _cancelSubs() {
    _txnSub?.cancel();
    _expSub?.cancel();
    _productSub?.cancel();
    _shiftSub?.cancel();
    _openShiftSub?.cancel();
  }

  void _listenTransactions(String arenaId) {
    _txnSub = _service.transactionsStream(arenaId).listen(
      (list) {
        transactions.assignAll(list);
        _recomputeStats(); // recompute without a separate Firestore call
      },
      onError: (e) => debugPrint('POS txn stream error: $e'),
    );
  }

  void _listenExpenses(String arenaId) {
    _expSub = _service.expensesStream(arenaId).listen(
      (list) {
        expenses.assignAll(list);
        _recomputeStats();
      },
      onError: (e) => debugPrint('POS expense stream error: $e'),
    );
  }

  /// Recompute today's KPIs locally from the already-streamed data.
  void _recomputeStats() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final todayTxns = transactions.where(
        (t) => !t.createdAt.isBefore(start) && t.createdAt.isBefore(end));
    final todayExp = expenses.where(
        (e) => !e.date.isBefore(start) && e.date.isBefore(end));

    double revenue = 0, paid = 0, remaining = 0, exp = 0;
    for (final t in todayTxns) {
      revenue += t.totalAmount;
      paid += t.amountPaid;
      remaining += t.remainingAmount;
    }
    for (final e in todayExp) {
      exp += e.amount;
    }
    todayRevenue.value = revenue;
    todayPaid.value = paid;
    todayRemaining.value = remaining;
    todayExpenses.value = exp;
    todayNet.value = paid - exp;
  }

  void _listenProducts(String arenaId) {
    _productSub = _service.productsStream(arenaId).listen(
          (list) => products.assignAll(list),
          onError: (e) => debugPrint('POS product stream error: $e'),
        );
  }

  void _listenShifts(String arenaId) {
    _shiftSub = _service.shiftsStream(arenaId).listen(
          (list) => shifts.assignAll(list),
          onError: (e) => debugPrint('POS shift stream error: $e'),
        );
  }

  void _listenOpenShift(String arenaId) {
    _openShiftSub = _service.openShiftStream(arenaId, _uid).listen(
          (shift) => openShift.value = shift,
          onError: (e) => debugPrint('POS open-shift stream error: $e'),
        );
  }

  Future<void> refreshStats() async {
    final arena = selectedArena.value;
    if (arena == null) return;
    statsLoading.value = true;
    try {
      final stats = await _service.todayStats(arena.id);
      todayRevenue.value = stats['revenue'] ?? 0;
      todayPaid.value = stats['paid'] ?? 0;
      todayRemaining.value = stats['remaining'] ?? 0;
      todayExpenses.value = stats['expenses'] ?? 0;
      todayNet.value = stats['net'] ?? 0;
    } catch (e) {
      debugPrint('POS stats error: $e');
    } finally {
      statsLoading.value = false;
    }
  }

  // ── Court live status ─────────────────────────────────────────────────

  /// Returns bookings for today's courts from the existing OwnerBookingController.
  List<BookingModel> todayBookingsForCourt(String courtId) {
    final now = DateTime.now();
    return OwnerBookingController.to.all.where((b) {
      return b.courtId == courtId &&
          b.date.year == now.year &&
          b.date.month == now.month &&
          b.date.day == now.day &&
          !b.isCancelled;
    }).toList()
      ..sort((a, b) => a.startHour.compareTo(b.startHour));
  }

  CourtLiveStatus courtStatus(String courtId) {
    final now = DateTime.now();
    final nowHour = now.hour;
    final bookings = todayBookingsForCourt(courtId);

    for (final b in bookings) {
      if (b.startHour <= nowHour && nowHour < b.startHour + b.totalHours) {
        return CourtLiveStatus.occupied;
      }
      if (b.startHour > nowHour && b.startHour <= nowHour + 2) {
        return CourtLiveStatus.upcoming;
      }
    }
    return CourtLiveStatus.available;
  }

  BookingModel? currentBookingForCourt(String courtId) {
    final now = DateTime.now();
    final nowHour = now.hour;
    return OwnerBookingController.to.all.firstWhereOrNull((b) =>
        b.courtId == courtId &&
        b.date.year == now.year &&
        b.date.month == now.month &&
        b.date.day == now.day &&
        b.startHour <= nowHour &&
        nowHour < b.startHour + b.totalHours &&
        !b.isCancelled);
  }

  // ── Transactions ──────────────────────────────────────────────────────

  Future<String> recordTransaction(PosTransactionModel txn) async {
    final id = await _service.createTransaction(txn);
    // Update open shift sales if applicable
    final shift = openShift.value;
    if (shift != null) {
      final isCash = txn.paymentMethod == PosPaymentMethod.cash;
      final isCard = txn.paymentMethod == PosPaymentMethod.card;
      await _service.updateShiftSales(
        shift.id,
        cashDelta: isCash ? txn.amountPaid : 0,
        cardDelta: isCard ? txn.amountPaid : 0,
        otherDelta: (!isCash && !isCard) ? txn.amountPaid : 0,
      );
    }
    refreshStats();
    return id;
  }

  // ── Expenses ──────────────────────────────────────────────────────────

  Future<void> addExpense(PosExpenseModel expense) async {
    final id = await _service.addExpense(expense);
    // Optimistic update — don't wait for stream
    final saved = PosExpenseModel(
      id: id,
      arenaId: expense.arenaId,
      arenaName: expense.arenaName,
      category: expense.category,
      amount: expense.amount,
      description: expense.description,
      date: expense.date,
      addedById: expense.addedById,
      addedByName: expense.addedByName,
      receiptRef: expense.receiptRef,
      shiftId: expense.shiftId,
    );
    expenses.insert(0, saved);
    _recomputeStats();
    final shift = openShift.value;
    if (shift != null && expense.category != ExpenseCategory.other) {
      await _service.updateShiftSales(shift.id, expenseDelta: expense.amount);
    }
  }

  Future<void> deleteExpense(String id) async {
    expenses.removeWhere((e) => e.id == id);
    _recomputeStats();
    await _service.deleteExpense(id);
  }

  // ── Products ──────────────────────────────────────────────────────────

  Future<void> saveProduct(PosProductModel product) =>
      _service.upsertProduct(product);

  Future<void> toggleProduct(String arenaId, String productId, bool active) =>
      _service.toggleProduct(arenaId, productId, active);

  Future<void> addProduct(PosProductModel product) async {
    final id = await _service.upsertProduct(product);
    final saved = PosProductModel(
      id: id,
      arenaId: product.arenaId,
      name: product.name,
      description: product.description,
      category: product.category,
      price: product.price,
      isActive: product.isActive,
      createdAt: product.createdAt,
    );
    if (saved.isActive) {
      products.add(saved);
      products.sort((a, b) => a.name.compareTo(b.name));
    }
  }

  Future<void> updateProduct(PosProductModel product) async {
    await _service.upsertProduct(product);
    final idx = products.indexWhere((p) => p.id == product.id);
    if (product.isActive) {
      if (idx >= 0) {
        products[idx] = product;
      } else {
        products.add(product);
      }
      products.sort((a, b) => a.name.compareTo(b.name));
    } else if (idx >= 0) {
      products.removeAt(idx);
    }
  }

  Future<void> deleteProduct(String id) async {
    products.removeWhere((p) => p.id == id);
    final arena = selectedArena.value;
    if (arena == null) throw Exception('No arena selected');
    await _service.deleteProduct(arena.id, id);
  }

  // ── Shifts ────────────────────────────────────────────────────────────

  Future<PosShiftModel> openNewShift(double openingCash) async {
    final arena = selectedArena.value;
    if (arena == null) throw Exception('No arena selected');
    final shift = PosShiftModel(
      id: '',
      arenaId: arena.id,
      arenaName: arena.name,
      staffId: _uid,
      staffName: _userName,
      status: ShiftStatus.open,
      openedAt: DateTime.now(),
      openingCash: openingCash,
    );
    return _service.openShift(shift);
  }

  Future<void> closeCurrentShift(double closingCash, String notes) async {
    final shift = openShift.value;
    if (shift == null) throw Exception('No open shift');
    await _service.closeShift(shift.id, closingCash, notes);
    refreshStats();
  }

  // ── Products helper ───────────────────────────────────────────────────

  PosProductModel? productById(String id) =>
      products.firstWhereOrNull((p) => p.id == id);

  @override
  void onClose() {
    _cancelSubs();
    super.onClose();
  }
}

enum CourtLiveStatus { available, upcoming, occupied, maintenance }

extension CourtLiveStatusX on CourtLiveStatus {
  String get label => switch (this) {
        CourtLiveStatus.available => 'Available',
        CourtLiveStatus.upcoming => 'Upcoming',
        CourtLiveStatus.occupied => 'Occupied',
        CourtLiveStatus.maintenance => 'Maintenance',
      };
}
