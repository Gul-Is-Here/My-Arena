import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/arena_model.dart';
import '../data/models/booking_model.dart';
import '../data/models/court_model.dart';
import '../data/models/promotion_model.dart';
import '../services/blocked_slot_service.dart';
import '../services/booking_service.dart';
import '../services/promotion_service.dart';
import '../utils/slot_status.dart';
import 'auth_controller.dart';

export '../utils/slot_status.dart' show SlotStatus;

class BookingController extends GetxController {
  final BookingService _service = BookingService();
  final ImagePicker _picker = ImagePicker();

  // ── My bookings stream ─────────────────────────────────────────────
  final RxList<BookingModel> bookings = <BookingModel>[].obs;
  StreamSubscription? _bookingsSub;
  StreamSubscription? _authSub;
  Timer? _retryTimer;

  List<BookingModel> get upcoming =>
      bookings.where((b) => b.isUpcoming).toList()
        ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

  List<BookingModel> get past => bookings
      .where((b) => !b.isUpcoming && !b.isCancelled)
      .toList()
    ..sort((a, b) => b.startDateTime.compareTo(a.startDateTime));

  List<BookingModel> get cancelled =>
      bookings.where((b) => b.isCancelled).toList()
        ..sort((a, b) => b.startDateTime.compareTo(a.startDateTime));

  // ── Draft state for the current booking flow ───────────────────────
  final Rxn<ArenaModel> arena = Rxn<ArenaModel>();
  final Rxn<CourtModel> court = Rxn<CourtModel>();
  final Rx<DateTime> date = DateTime.now().obs;
  final RxSet<int> selectedHours = <int>{}.obs;
  final RxInt selectedDuration = 1.obs;

  // Booked slots loaded from Firestore for the current date+court
  final RxList<BookingModel> _bookedSlots = <BookingModel>[].obs;
  final RxSet<int> _blockedHours = <int>{}.obs;
  // Real-time set of locked hours from slotLocks stream — primary source of truth.
  final RxSet<int> _lockedHours = <int>{}.obs;
  StreamSubscription? _slotLocksSub;
  final BlockedSlotService _blockedService = BlockedSlotService();
  final PromotionService _promoService = PromotionService();
  final RxBool loadingSlots = false.obs;

  // ── Promo code state (booking summary) ────────────────────────────
  final Rxn<PromotionModel> appliedPromo = Rxn<PromotionModel>();
  final RxBool promoLoading = false.obs;
  final RxnString promoError = RxnString();

  // ── Available offers for current arena (loaded at flow start) ─────
  final RxList<PromotionModel> arenaOffers = <PromotionModel>[].obs;
  final RxBool offersLoading = false.obs;

  // ── Recurring ──────────────────────────────────────────────────────────
  final RxBool isRecurring = false.obs;
  final RxInt recurringWeeks = RxInt(4);

  // ── Group booking ──────────────────────────────────────────────────────
  final RxBool isGroupBooking = false.obs;
  final RxInt groupSize = RxInt(2);

  // ── Waitlist ───────────────────────────────────────────────────────────
  final RxList<Map<String, dynamic>> waitlistItems = <Map<String, dynamic>>[].obs;
  StreamSubscription? _waitlistSub;

  BookingModel? draft;

  // JazzCash number from settings/booking
  final RxString jazzCashNumber = '0300-1234567'.obs;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void onInit() {
    super.onInit();
    // Controller is permanent — re-subscribe whenever the signed-in user
    // changes so the list never goes stale across logins.
    _authSub = FirebaseAuth.instance
        .authStateChanges()
        .listen((user) {
      _listenBookings(user?.uid);
      _listenWaitlist(user?.uid);
    });
    _listenBookings(_uid);
    _listenWaitlist(_uid);
    _loadSettings();
  }

  void _listenBookings(String? uid) {
    _retryTimer?.cancel();
    _bookingsSub?.cancel();
    _bookingsSub = null;
    if (uid == null || uid.isEmpty) {
      bookings.clear();
      return;
    }
    _bookingsSub = _service.customerBookings(uid).listen(
      (list) {
        bookings.assignAll(list);
      },
      onError: (e) {
        debugPrint('customerBookings stream error: $e');
        _retryTimer =
            Timer(const Duration(seconds: 8), () => _listenBookings(_uid));
      },
    );
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('booking')
          .get();
      if (doc.exists) {
        jazzCashNumber.value =
            doc.data()?['jazzCashNumber'] ?? jazzCashNumber.value;
      }
    } catch (_) {}
  }

  Future<String?> joinWaitlist({
    required String arenaId,
    required String arenaName,
    required String courtId,
    required DateTime date,
    required int hour,
  }) async {
    final uid = _uid;
    if (uid.isEmpty) return 'Not logged in';

    // Block if the customer already has an active booking on this slot
    final slotDate = Timestamp.fromDate(DateTime(date.year, date.month, date.day));
    final activeStatuses = ['deposit_submitted', 'confirmed'];
    final existing = await FirebaseFirestore.instance
        .collection('bookings')
        .where('customerId', isEqualTo: uid)
        .where('courtId', isEqualTo: courtId)
        .where('date', isEqualTo: slotDate)
        .where('status', whereIn: activeStatuses)
        .get();
    final overlap = existing.docs.any((d) {
      final data = d.data();
      final start = (data['startHour'] as int?) ?? 0;
      final total = (data['totalHours'] as int?) ?? 1;
      return hour >= start && hour < start + total;
    });
    if (overlap) return 'You already have a booking for this slot';

    final dateKey =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    await FirebaseFirestore.instance
        .collection('waitlist')
        .doc('${uid}_${arenaId}_${courtId}_${dateKey}_$hour')
        .set({
      'arenaId': arenaId,
      'arenaName': arenaName,
      'courtId': courtId,
      'date': slotDate,
      'hour': hour,
      'customerId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return null; // success
  }

  void _listenWaitlist(String? uid) {
    _waitlistSub?.cancel();
    if (uid == null || uid.isEmpty) {
      waitlistItems.clear();
      return;
    }
    _waitlistSub = _service.waitlistItems(uid).listen(
      (items) => waitlistItems.assignAll(items),
      onError: (_) {},
    );
  }

  void startFlow(ArenaModel a, CourtModel c) {
    arena.value = a;
    court.value = c;
    date.value = DateTime.now();
    selectedHours.clear();
    selectedDuration.value = 1;
    isRecurring.value = false;
    recurringWeeks.value = 4;
    isGroupBooking.value = false;
    groupSize.value = 2;
    draft = null;
    clearPromo();
    arenaOffers.clear();
    _bookedSlots.clear();
    _blockedHours.clear();
    _lockedHours.clear();
    _subscribeSlotLocks();
  }

  void selectCourt(CourtModel c) {
    court.value = c;
    selectedHours.clear();
    _subscribeSlotLocks();
  }

  void selectDate(DateTime d) {
    date.value = d;
    selectedHours.clear();
    _subscribeSlotLocks();
  }

  /// Subscribes to real-time slotLocks for the current court+date.
  /// Cancels any existing subscription first so court/date changes always
  /// result in a fresh stream. Also loads blockedHours (one-shot is fine
  /// there since blocked slots change infrequently).
  void _subscribeSlotLocks() {
    final c = court.value;
    if (c == null) return;
    loadingSlots.value = true;
    _slotLocksSub?.cancel();
    _slotLocksSub = _service
        .bookedHoursStream(c.id, date.value)
        .listen((hours) {
      // If the user already selected a slot that just became taken, clear it
      // and show a message so they don't proceed to payment with a stale slot.
      final conflict = selectedHours.any(hours.contains);
      _lockedHours.assignAll(hours);
      loadingSlots.value = false;
      if (conflict) {
        selectedHours.clear();
        Get.snackbar(
          'Slot no longer available',
          'This court has just been booked for that time. Please choose another.',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
        );
      }
    }, onError: (_) {
      loadingSlots.value = false;
    });

    // Blocked hours are owner-managed and change rarely — one-shot is fine.
    _blockedService
        .blockedHours(arena.value?.id ?? '', c.id, date.value)
        .then((h) => _blockedHours.assignAll(h))
        .catchError((_) {});
  }

  List<int> hoursFor(CourtModel c) {
    final start = int.parse(c.startTime.split(':').first);
    var end = int.parse(c.endTime.split(':').first);
    if (end <= start) end += 24;
    return [for (var h = start; h < end; h++) h];
  }

  SlotStatus slotStatus(int hour) => computeSlotStatus(
        date: date.value,
        hour: hour,
        bookedSlots: _bookedSlots,
        blockedHours: _blockedHours,
        lockedHours: _lockedHours,
      );

  // ── Promo helpers ─────────────────────────────────────────────────

  void clearPromo() {
    appliedPromo.value = null;
    promoError.value = null;
  }

  /// Loads all active offers for the current arena (for discovery UI).
  Future<void> loadOffersForArena() async {
    final arenaId = arena.value?.id;
    if (arenaId == null) return;
    offersLoading.value = true;
    try {
      final offers = await _promoService.fetchActiveForArena(arenaId);
      arenaOffers.assignAll(offers);
    } catch (_) {
      arenaOffers.clear();
    } finally {
      offersLoading.value = false;
    }
  }

  /// Applies [promo] directly (from offer card tap — no code needed).
  Future<void> applyOffer(PromotionModel promo) async {
    promoError.value = null;
    // Apply immediately for instant UI feedback, then validate in background.
    appliedPromo.value = promo;
    _claimPromo(promo.id, promo).catchError((e) {
      // Revert if the backend rejects (e.g. maxUses just hit by another user).
      if (appliedPromo.value?.id == promo.id) appliedPromo.value = null;
    });
  }

  Future<void> applyPromoCode(String code) async {
    final arenaId = arena.value?.id;
    if (arenaId == null) return;

    promoError.value = null;
    promoLoading.value = true;
    try {
      final promo = await _promoService.findActive(arenaId, code);
      if (promo == null) {
        promoError.value = 'Invalid or expired promo code.';
        appliedPromo.value = null;
        return;
      }
      await _claimPromo(promo.id, promo);
      appliedPromo.value = promo;
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        promoError.value = e.message ?? 'Could not validate code. Try again.';
      } else {
        promoError.value = 'Could not validate code. Try again.';
      }
    } finally {
      promoLoading.value = false;
    }
  }

  // Calls the backend transaction that atomically checks + increments maxUses.
  // Callers that optimistically set appliedPromo before calling must revert on error.
  Future<void> _claimPromo(String promoId, PromotionModel promo) async {
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('validateAndApplyPromo');
      await fn.call({'promoId': promoId, 'bookingTotal': totalAmount});
    } on FirebaseFunctionsException catch (e) {
      promoError.value = e.message ?? 'Offer could not be applied. Try again.';
      rethrow;
    }
  }

  /// Best eligible offer from [arenaOffers] for the current booking total.
  /// Platform promos are preferred; among same scope, highest saving wins.
  PromotionModel? get recommendedOffer {
    final eligible = arenaOffers
        .where((p) => p.isEligibleFor(totalAmount))
        .toList();
    if (eligible.isEmpty) return null;
    eligible.sort((a, b) {
      // Platform first.
      if (a.isPlatform && !b.isPlatform) return -1;
      if (!a.isPlatform && b.isPlatform) return 1;
      // Higher saving first.
      return b.discountFor(totalAmount).compareTo(a.discountFor(totalAmount));
    });
    return eligible.first;
  }

  /// "Almost unlocked" offer: the one with the lowest minBookingAmount that
  /// the customer hasn't met yet, and where the gap is within 50% of current total.
  PromotionModel? get almostUnlockedOffer {
    final t = totalAmount;
    final candidates = arenaOffers
        .where((p) =>
            p.isActive &&
            p.minBookingAmount != null &&
            t < p.minBookingAmount! &&
            (p.minBookingAmount! - t) <= t * 0.5)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) =>
        a.minBookingAmount!.compareTo(b.minBookingAmount!));
    return candidates.first;
  }

  double get promoDiscount {
    final promo = appliedPromo.value;
    if (promo == null || draft == null) return 0;
    final base = (draft!.totalAmountStored ?? draft!.pricePerHour * draft!.totalHours) +
        draft!.posAddOnsTotal - draft!.posDiscount;
    return promo.discountFor(base);
  }

  void setDuration(int hours) {
    if (selectedDuration.value == hours) return;
    selectedDuration.value = hours;
    selectedHours.clear();
  }

  /// Selects the [selectedDuration]-hour block starting at [hour]. Taps the
  /// same already-selected block again to deselect. Refuses to select if any
  /// hour in the block isn't available.
  void selectSlot(int hour) {
    final dur = selectedDuration.value;
    final range = [for (var i = 0; i < dur; i++) hour + i];

    if (selectedHours.length == dur && range.every(selectedHours.contains)) {
      selectedHours.clear();
      return;
    }
    for (final h in range) {
      if (slotStatus(h) != SlotStatus.available) return;
    }
    selectedHours
      ..clear()
      ..addAll(range);
  }

  int get startHour =>
      selectedHours.isEmpty ? 0 : selectedHours.reduce((a, b) => a < b ? a : b);
  int get totalHours => selectedHours.length;

  /// Live availability check against slotLocks for all selected hours across
  /// all recurring weeks. Called before every navigation step.
  /// Returns null when all slots are free, or a descriptive error string.
  /// The Firestore transaction inside createBookingWithDeposit is the final
  /// atomic concurrency barrier against race conditions.
  Future<String?> validateSlots() async {
    final c = court.value;
    if (c == null || selectedHours.isEmpty) return 'No slot selected.';
    final db = FirebaseFirestore.instance;
    final weeks = isRecurring.value ? recurringWeeks.value : 1;

    for (var week = 0; week < weeks; week++) {
      final weekDate = date.value.add(Duration(days: 7 * week));
      final dateStr =
          '${weekDate.year}${weekDate.month.toString().padLeft(2, '0')}${weekDate.day.toString().padLeft(2, '0')}';
      for (final h in selectedHours) {
        final key = '${c.id}_${dateStr}_${h.toString().padLeft(2, '0')}';
        final snap = await db.collection('slotLocks').doc(key).get();
        if (snap.exists) {
          selectedHours.clear();
          final label = week == 0 ? 'This slot' : 'Week ${week + 1}';
          return '$label is already booked. Please choose another time.';
        }
      }
    }
    return null;
  }

  double get totalAmount {
    final c = court.value;
    if (c == null) return 0;
    return selectedHours.fold(0.0, (s, h) => s + c.priceAt(h));
  }

  double get netTotalAmount => (totalAmount - promoDiscount).clamp(0, double.infinity);
  double get depositAmount =>
      netTotalAmount * BookingSettings.depositPercent / 100;
  double get remainingAmount => netTotalAmount - depositAmount;

  bool isPeak(int hour) => court.value?.isPeak(hour) ?? false;

  void buildDraft() {
    final a = arena.value!;
    final c = court.value!;
    final groupId = isRecurring.value
        ? _generateId()
        : null;
    final code = isGroupBooking.value ? _generateJoinCode() : null;
    draft = BookingModel(
      id: '',
      arenaId: a.id,
      arenaName: a.name,
      courtId: c.id,
      courtName: c.name,
      customerId: _uid,
      customerName: AuthController.to.currentUser.value?.name ?? '',
      ownerId: a.ownerId,
      date: DateTime(date.value.year, date.value.month, date.value.day),
      startHour: startHour,
      totalHours: totalHours,
      pricePerHour: c.pricePerHour,
      createdAt: DateTime.now(),
      totalAmountStored: totalAmount != c.pricePerHour * totalHours
          ? totalAmount
          : null,
      recurringGroupId: groupId,
      recurringTotal: isRecurring.value ? recurringWeeks.value : null,
      isGroupBooking: isGroupBooking.value,
      groupSize: isGroupBooking.value ? groupSize.value : 1,
      joinCode: code,
      appliedPromoId: appliedPromo.value?.id,
      appliedPromoCode: appliedPromo.value?.code,
      promoDiscount: promoDiscount,
      appliedPromoScope: appliedPromo.value?.scope.name,
    );
  }

  String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = DateTime.now().microsecondsSinceEpoch;
    return List.generate(20, (i) => chars[(rand >> i) % chars.length]).join();
  }

  String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = DateTime.now().microsecondsSinceEpoch;
    return List.generate(6, (i) => chars[(rand >> (i * 5)) % chars.length]).join();
  }

  // Returns picked file or null if user cancelled
  Future<XFile?> pickDepositScreenshot() =>
      _picker.pickImage(source: ImageSource.gallery);

  Future<String> submitDeposit(XFile screenshot, String accountUsed) async {
    final b = draft!;
    final promoIdToRollback = appliedPromo.value?.id;
    String bookingId;
    try {
      if (b.isRecurring && b.recurringTotal != null && b.recurringTotal! > 1) {
        final ids = await _service.createRecurringBookings(
          b,
          b.recurringTotal!,
          depositScreenshot: screenshot,
          depositAccount: accountUsed,
        );
        bookingId = ids.first;
      } else {
        bookingId = await _service.createBookingWithDeposit(
          b,
          screenshot: screenshot,
          accountUsed: accountUsed,
        );
      }
    } catch (e) {
      // Booking creation failed — roll back the promo usage count so the
      // customer can try again without permanently consuming the promotion.
      if (promoIdToRollback != null) {
        _rollbackPromo(promoIdToRollback).catchError(
          (err) => debugPrint('rollbackPromo failed: $err'),
        );
      }
      rethrow;
    }
    draft = null;
    selectedHours.clear();
    // usageCount was already incremented atomically by validateAndApplyPromo
    // Cloud Function when the offer was applied. Do NOT call recordUsage here
    // or it would double-count.
    clearPromo();
    return bookingId;
  }

  Future<void> _rollbackPromo(String promoId) async {
    final fn = FirebaseFunctions.instanceFor(region: 'asia-south1')
        .httpsCallable('rollbackPromo');
    await fn.call({'promoId': promoId});
  }

  Future<void> cancelRecurringSeries(String recurringGroupId) async {
    await _service.cancelRecurringSeries(recurringGroupId, _uid);
  }

  Future<BookingModel?> joinGroupBooking(String joinCode) async {
    final user = AuthController.to.currentUser.value;
    if (user == null) return null;
    return _service.joinGroupBooking(joinCode, user.uid, user.name);
  }

  Future<void> cancelWaitlistItem(String docId) =>
      _service.cancelWaitlistItem(docId);

  Future<void> cancelBooking(
      String id, String bankName, String accountNumber) async {
    final b = bookings.firstWhereOrNull((x) => x.id == id);
    if (b == null) return;
    final refund =
        b.depositAmount * (100 - BookingSettings.cancellationDeductPercent) / 100;
    await _service.cancelBooking(
      id,
      refundAmount: refund,
      customerAccount: {'bankName': bankName, 'accountNumber': accountNumber},
    );
  }

  @override
  void onClose() {
    _retryTimer?.cancel();
    _authSub?.cancel();
    _bookingsSub?.cancel();
    _waitlistSub?.cancel();
    _slotLocksSub?.cancel();
    super.onClose();
  }
}
