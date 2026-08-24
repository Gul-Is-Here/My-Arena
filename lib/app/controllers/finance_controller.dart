import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../data/models/audit_log_model.dart';
import '../data/models/booking_model.dart';
import '../data/models/payout_model.dart';
import '../data/models/user_model.dart';
import '../services/audit_service.dart';
import '../theme/app_colors.dart';

enum FinanceDateRange { today, week, month, year, custom }

extension FinanceDateRangeX on FinanceDateRange {
  String get label => switch (this) {
        FinanceDateRange.today => 'Today',
        FinanceDateRange.week => 'This Week',
        FinanceDateRange.month => 'This Month',
        FinanceDateRange.year => 'This Year',
        FinanceDateRange.custom => 'Custom',
      };

  DateTimeRange get range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      FinanceDateRange.today => DateTimeRange(start: today, end: now),
      FinanceDateRange.week => DateTimeRange(
          start: today.subtract(Duration(days: today.weekday - 1)),
          end: now),
      FinanceDateRange.month =>
        DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      FinanceDateRange.year =>
        DateTimeRange(start: DateTime(now.year, 1, 1), end: now),
      FinanceDateRange.custom =>
        DateTimeRange(start: today.subtract(const Duration(days: 30)), end: now),
    };
  }
}

class FinanceController extends GetxController {
  static FinanceController get to => Get.find();

  final _db = FirebaseFirestore.instance;
  AuditService get _audit => Get.find<AuditService>();

  // ── Date range ─────────────────────────────────────────────────────────
  final Rx<FinanceDateRange> dateRange = FinanceDateRange.month.obs;
  final Rx<DateTime?> customStart = Rx<DateTime?>(null);
  final Rx<DateTime?> customEnd = Rx<DateTime?>(null);

  // ── Bookings data ──────────────────────────────────────────────────────
  final RxList<BookingModel> completedBookings = <BookingModel>[].obs;
  final RxList<PayoutModel> payouts = <PayoutModel>[].obs;
  final RxList<UserModel> owners = <UserModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isActionLoading = false.obs;

  StreamSubscription? _bookingSub;
  StreamSubscription? _payoutSub;
  StreamSubscription? _ownerSub;

  @override
  void onInit() {
    super.onInit();
    ever(dateRange, (_) => _reload());
    ever(customStart, (_) => _reload());
    ever(customEnd, (_) => _reload());
    _reload();
    _ownerSub = _db
        .collection('users')
        .where('role', isEqualTo: 'owner')
        .snapshots()
        .listen((s) => owners.assignAll(
              s.docs.map((d) => UserModel.fromMap({...d.data(), 'uid': d.id})).toList(),
            ));
  }

  @override
  void onClose() {
    _bookingSub?.cancel();
    _payoutSub?.cancel();
    _ownerSub?.cancel();
    super.onClose();
  }

  DateTimeRange get _activeRange {
    if (dateRange.value == FinanceDateRange.custom &&
        customStart.value != null &&
        customEnd.value != null) {
      return DateTimeRange(start: customStart.value!, end: customEnd.value!);
    }
    return dateRange.value.range;
  }

  void _reload() {
    isLoading.value = true;
    final range = _activeRange;

    _bookingSub?.cancel();
    _bookingSub = _db
        .collection('bookings')
        .where('status', isEqualTo: BookingStatus.completed.key)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(range.end))
        .orderBy('date', descending: true)
        .snapshots()
        .listen((s) {
      completedBookings.assignAll(
        s.docs.map((d) => BookingModel.fromMap({...d.data(), 'id': d.id})).toList(),
      );
      isLoading.value = false;
    });

    _payoutSub?.cancel();
    _payoutSub = _db
        .collection('payouts')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .listen((s) => payouts.assignAll(
              s.docs.map((d) => PayoutModel.fromMap(d.data(), d.id)).toList(),
            ));
  }

  // ── Derived metrics ────────────────────────────────────────────────────

  double get _commissionRate => 0.10; // 10% platform fee

  double get totalRevenue =>
      completedBookings.fold(0.0, (sum, b) => sum + b.totalAmount);

  double get platformCommission => totalRevenue * _commissionRate;

  double get ownerEarnings => totalRevenue - platformCommission;

  double get pendingPayouts {
    final paid = payouts
        .where((p) => p.status == PayoutStatus.paid)
        .fold(0.0, (s, p) => s + p.amount);
    return (ownerEarnings - paid).clamp(0.0, double.infinity);
  }

  double get completedPayoutsTotal => payouts
      .where((p) => p.status == PayoutStatus.paid)
      .fold(0.0, (s, p) => s + p.amount);

  double get refundTotal => completedBookings
      .where((b) =>
          b.status == BookingStatus.refundPending ||
          b.status == BookingStatus.refundSent ||
          b.status == BookingStatus.refundConfirmed)
      .fold(0.0, (s, b) => s + b.totalAmount);

  // ── Per-owner summary ──────────────────────────────────────────────────

  List<OwnerFinanceSummary> get ownerSummaries {
    final Map<String, List<BookingModel>> byOwner = {};
    for (final b in completedBookings) {
      byOwner.putIfAbsent(b.ownerId, () => []).add(b);
    }

    final Map<String, List<PayoutModel>> payoutsByOwner = {};
    for (final p in payouts) {
      payoutsByOwner.putIfAbsent(p.ownerId, () => []).add(p);
    }

    return owners.map((owner) {
      final ownerBookings = byOwner[owner.uid] ?? [];
      final gross = ownerBookings.fold(0.0, (s, b) => s + b.totalAmount);
      final earned = gross * (1 - _commissionRate);
      final ownerPayouts = payoutsByOwner[owner.uid] ?? [];
      final paid = ownerPayouts
          .where((p) => p.status == PayoutStatus.paid)
          .fold(0.0, (s, p) => s + p.amount);
      final lastPayout = ownerPayouts.isNotEmpty &&
              ownerPayouts.first.paidAt != null
          ? ownerPayouts.first.paidAt
          : null;
      return OwnerFinanceSummary(
        ownerId: owner.uid,
        ownerName: owner.name,
        totalEarned: earned,
        totalPaid: paid,
        totalPending: (earned - paid).clamp(0.0, double.infinity),
        lastPayoutAt: lastPayout,
        bookingCount: ownerBookings.length,
      );
    }).where((s) => s.bookingCount > 0 || s.totalPaid > 0).toList()
      ..sort((a, b) => b.totalPending.compareTo(a.totalPending));
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> markPaid(
    OwnerFinanceSummary summary, {
    required String paymentMethod,
    String notes = '',
  }) async {
    isActionLoading.value = true;
    try {
      final actor = Get.find<AuthController>().currentUser.value;
      final now = DateTime.now();

      // Collect booking IDs for this owner in the current range
      final bookingIds = completedBookings
          .where((b) => b.ownerId == summary.ownerId)
          .map((b) => b.id)
          .toList();

      final doc = _db.collection('payouts').doc();
      await doc.set({
        'ownerId': summary.ownerId,
        'ownerName': summary.ownerName,
        'amount': summary.totalPending,
        'bookingRefs': bookingIds,
        'paidById': actor?.uid ?? '',
        'paidByName': actor?.name ?? '',
        'paidAt': Timestamp.fromDate(now),
        'paymentMethod': paymentMethod,
        'notes': notes,
        'status': PayoutStatus.paid.value,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _audit.log(
        action: AuditAction.payoutMarkedPaid,
        entityType: 'payout',
        entityId: doc.id,
        newData: {
          'ownerId': summary.ownerId,
          'ownerName': summary.ownerName,
          'amount': summary.totalPending,
          'method': paymentMethod,
        },
      );

      _snack('Payout of PKR ${summary.totalPending.toStringAsFixed(0)} marked paid');
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      isActionLoading.value = false;
    }
  }

  void _snack(String msg, {bool isError = false}) {
    Get.snackbar(
      isError ? 'Error' : 'Done',
      msg,
      backgroundColor: isError ? AppColors.error : AppColors.elevated,
      colorText: AppColors.textPrimary,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }
}
