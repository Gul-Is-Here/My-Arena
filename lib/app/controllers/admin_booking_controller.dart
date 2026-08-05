import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/audit_log_model.dart';
import '../data/models/booking_model.dart';
import '../services/audit_service.dart';
import '../theme/app_colors.dart';

/// Admin Booking Management — paginated, searchable, filterable.
class AdminBookingController extends GetxController {
  static AdminBookingController get to => Get.find();

  final _db = FirebaseFirestore.instance;
  AuditService get _audit => Get.find<AuditService>();

  // ── Filters ────────────────────────────────────────────────────────────
  final RxString searchQuery = ''.obs;
  final Rx<BookingStatus?> statusFilter = Rx<BookingStatus?>(null);
  final Rx<DateTime?> dateFrom = Rx<DateTime?>(null);
  final Rx<DateTime?> dateTo = Rx<DateTime?>(null);

  // ── State ──────────────────────────────────────────────────────────────
  final RxList<BookingModel> bookings = <BookingModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasMore = true.obs;
  final RxBool isActionLoading = false.obs;

  static const int _pageSize = 20;
  DocumentSnapshot? _lastDoc;
  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    loadFirst();
    // Re-load when filters change, debounced
    debounce(searchQuery, (_) => loadFirst(), time: const Duration(milliseconds: 400));
    ever(statusFilter, (_) => loadFirst());
    ever(dateFrom, (_) => loadFirst());
    ever(dateTo, (_) => loadFirst());
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void loadFirst() {
    _lastDoc = null;
    hasMore.value = true;
    bookings.clear();
    _fetchPage();
  }

  Future<void> loadMore() async {
    if (!hasMore.value || isLoading.value) return;
    _fetchPage();
  }

  void _fetchPage() {
    isLoading.value = true;
    var q = _db
        .collection('bookings')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    final status = statusFilter.value;
    if (status != null) {
      q = q.where('status', isEqualTo: status.key);
    }
    if (dateFrom.value != null) {
      q = q.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dateFrom.value!));
    }
    if (dateTo.value != null) {
      q = q.where('date',
          isLessThanOrEqualTo: Timestamp.fromDate(dateTo.value!));
    }
    if (_lastDoc != null) q = q.startAfterDocument(_lastDoc!);

    _sub?.cancel();
    _sub = q.snapshots().listen((snap) {
      isLoading.value = false;
      final page = snap.docs
          .map((d) => BookingModel.fromMap({...d.data(), 'id': d.id}))
          .toList();
      if (_lastDoc == null) {
        bookings.assignAll(page);
      } else {
        bookings.addAll(page);
      }
      if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
      hasMore.value = snap.docs.length >= _pageSize;
    });
  }

  /// Client-side search on the already-loaded page (name / arena / id).
  List<BookingModel> get filtered {
    final q = searchQuery.value.toLowerCase();
    if (q.isEmpty) return bookings;
    return bookings.where((b) {
      return b.customerName.toLowerCase().contains(q) ||
          b.arenaName.toLowerCase().contains(q) ||
          b.id.toLowerCase().contains(q);
    }).toList();
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> cancelBooking(BookingModel b, {String? reason}) async {
    await _action(() async {
      await _db.collection('bookings').doc(b.id).update({
        'status': BookingStatus.cancelled.key,
      });
      await _audit.log(
        action: AuditAction.bookingCancelledAdmin,
        entityType: 'booking',
        entityId: b.id,
        oldData: {'status': b.status.key},
        newData: {
          'status': BookingStatus.cancelled.key,
          'customerName': b.customerName,
          'arenaName': b.arenaName,
        },
        reason: reason,
      );
    });
    _snack('Booking cancelled');
  }

  Future<void> approveBooking(BookingModel b) async {
    await _action(() async {
      await _db.collection('bookings').doc(b.id).update({
        'status': BookingStatus.confirmed.key,
      });
      await _audit.log(
        action: AuditAction.bookingApprovedAdmin,
        entityType: 'booking',
        entityId: b.id,
        oldData: {'status': b.status.key},
        newData: {'status': BookingStatus.confirmed.key},
      );
    });
    _snack('Booking approved');
  }

  Future<void> forceComplete(BookingModel b) async {
    await _action(() async {
      await _db.collection('bookings').doc(b.id).update({
        'status': BookingStatus.completed.key,
        'checkedIn': true,
      });
      await _audit.log(
        action: AuditAction.bookingForceCompleted,
        entityType: 'booking',
        entityId: b.id,
        oldData: {'status': b.status.key},
        newData: {'status': BookingStatus.completed.key},
      );
    });
    _snack('Booking force-completed');
  }

  Future<void> refundBooking(BookingModel b, {String? reason}) async {
    await _action(() async {
      await _db.collection('bookings').doc(b.id).update({
        'status': BookingStatus.refundPending.key,
      });
      await _audit.log(
        action: AuditAction.bookingRefundedAdmin,
        entityType: 'booking',
        entityId: b.id,
        oldData: {'status': b.status.key},
        newData: {
          'status': BookingStatus.refundPending.key,
          'amount': b.totalAmount,
        },
        reason: reason,
      );
    });
    _snack('Refund initiated');
  }

  Future<void> _action(Future<void> Function() fn) async {
    isActionLoading.value = true;
    try {
      await fn();
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
