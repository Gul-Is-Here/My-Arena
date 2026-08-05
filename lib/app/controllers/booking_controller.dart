import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/arena_model.dart';
import '../data/models/booking_model.dart';
import '../data/models/court_model.dart';
import '../services/blocked_slot_service.dart';
import '../services/booking_service.dart';
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
  final BlockedSlotService _blockedService = BlockedSlotService();
  final RxBool loadingSlots = false.obs;

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
        _autoCompleteExpired(list);
      },
      onError: (e) {
        debugPrint('customerBookings stream error: $e');
        _retryTimer =
            Timer(const Duration(seconds: 8), () => _listenBookings(_uid));
      },
    );
  }

  // Fallback for the scheduled Cloud Function: confirmed bookings whose end
  // time has passed are marked completed from the client too, so the status
  // flips even if the server-side job hasn't run yet.
  final Set<String> _autoCompleting = {};

  void _autoCompleteExpired(List<BookingModel> list) {
    final now = DateTime.now();
    for (final b in list) {
      if (b.status == BookingStatus.confirmed &&
          b.endDateTime.isBefore(now) &&
          !_autoCompleting.contains(b.id)) {
        _autoCompleting.add(b.id);
        FirebaseFirestore.instance
            .collection('bookings')
            .doc(b.id)
            .update({
          'status': BookingStatus.completed.key,
          'completedAt': FieldValue.serverTimestamp(),
          if (!b.checkedIn) 'noShow': true,
        }).catchError((e) {
          _autoCompleting.remove(b.id);
          debugPrint('auto-complete failed for ${b.id}: $e');
        });
      }
    }
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
    _bookedSlots.clear();
    _blockedHours.clear();
    _loadBookedSlots();
  }

  void selectCourt(CourtModel c) {
    court.value = c;
    selectedHours.clear();
    _loadBookedSlots();
  }

  void selectDate(DateTime d) {
    date.value = d;
    selectedHours.clear();
    _loadBookedSlots();
  }

  Future<void> _loadBookedSlots() async {
    final c = court.value;
    if (c == null) return;
    loadingSlots.value = true;
    try {
      final slots = await _service.bookedSlots(c.id, date.value);
      _bookedSlots.assignAll(slots);
      _blockedHours.assignAll(await _blockedService.blockedHours(
          arena.value?.id ?? '', c.id, date.value));
    } catch (_) {
    } finally {
      loadingSlots.value = false;
    }
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
      );

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

  double get totalAmount {
    final c = court.value;
    if (c == null) return 0;
    return selectedHours.fold(0.0, (s, h) => s + c.priceAt(h));
  }

  double get depositAmount =>
      totalAmount * BookingSettings.depositPercent / 100;
  double get remainingAmount => totalAmount - depositAmount;

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

  Future<String> submitDeposit(File screenshot, String accountUsed) async {
    final b = draft!;
    String bookingId;
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
    draft = null;
    selectedHours.clear();
    return bookingId;
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
    super.onClose();
  }
}
