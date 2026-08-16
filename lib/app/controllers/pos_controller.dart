import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../data/models/arena_model.dart';
import '../data/models/booking_model.dart';
import '../data/models/pos_expense_model.dart';
import '../data/models/pos_product_model.dart';
import '../data/models/pos_shift_model.dart';
import '../data/models/pos_transaction_model.dart';
import '../services/ledger_service.dart'; // also exports LedgerSource via pos_transaction_model
import '../services/pos_service.dart';
import 'auth_controller.dart';
import 'owner_booking_controller.dart';
import 'owner_controller.dart';

class PosController extends GetxController {
  static PosController get to => Get.find();

  final PosService _service = PosService();
  final LedgerService _ledger = LedgerService();

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
  // Breakdown: online deposit vs counter collection
  final RxDouble todayOnlineCollected = 0.0.obs;
  final RxDouble todayCounterCollected = 0.0.obs;

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
    double onlineCollected = 0, counterCollected = 0;
    for (final t in todayTxns) {
      revenue += t.totalAmount;
      paid += t.amountPaid;
      remaining += t.remainingAmount;
      if (t.source == LedgerSource.online) {
        onlineCollected += t.amountPaid;
      } else {
        counterCollected += t.amountPaid;
      }
    }
    for (final e in todayExp) {
      exp += e.amount;
    }
    todayRevenue.value = revenue;
    todayPaid.value = paid;
    todayRemaining.value = remaining;
    todayExpenses.value = exp;
    todayNet.value = paid - exp;
    todayOnlineCollected.value = onlineCollected;
    todayCounterCollected.value = counterCollected;
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
      // An ongoing booking always holds the court, even past its original end time.
      if (b.status == BookingStatus.ongoing) return CourtLiveStatus.occupied;
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
        !b.isCancelled &&
        // Ongoing bookings hold the court even past the original end time.
        (b.status == BookingStatus.ongoing ||
            (b.startHour <= nowHour && nowHour < b.startHour + b.totalHours)));
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
    await _service.addExpense(expense);
    // Stream will update expenses list via _listenExpenses → assignAll.
    // No manual insert here — that caused double-add (same race as addProduct).
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

  Future<void> addProduct(PosProductModel product) =>
      _service.upsertProduct(product);

  Future<void> updateProduct(PosProductModel product) =>
      _service.upsertProduct(product);

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

  // ── Balance collection ────────────────────────────────────────────────

  /// Collect outstanding balance from an online booking at the counter.
  Future<void> collectBalance({
    required BookingModel booking,
    required double amount,
    required PosPaymentMethod method,
    String? refNo,
    String? notes,
  }) async {
    await _ledger.collectBalance(
      booking: booking,
      amount: amount,
      method: method,
      refNo: refNo,
      shiftId: openShift.value?.id,
      notes: notes,
    );

    final isCash = method == PosPaymentMethod.cash;
    final isCard = method == PosPaymentMethod.card;
    final shift = openShift.value;
    if (shift != null) {
      await _service.updateShiftSales(
        shift.id,
        cashDelta: isCash ? amount : 0,
        cardDelta: isCard ? amount : 0,
        otherDelta: (!isCash && !isCard) ? amount : 0,
      );
    }
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
