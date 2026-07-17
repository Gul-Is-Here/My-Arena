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
  final RxBool loadingSlots = false.obs;

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
        .listen((user) => _listenBookings(user?.uid));
    _listenBookings(_uid);
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
      (list) => bookings.assignAll(list),
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

  Future<void> joinWaitlist({
    required String arenaId,
    required String arenaName,
    required String courtId,
    required DateTime date,
    required int hour,
  }) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    final dateKey =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    await FirebaseFirestore.instance
        .collection('waitlist')
        .doc('${uid}_${arenaId}_${courtId}_${dateKey}_$hour')
        .set({
      'arenaId': arenaId,
      'arenaName': arenaName,
      'courtId': courtId,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'hour': hour,
      'customerId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void startFlow(ArenaModel a, CourtModel c) {
    arena.value = a;
    court.value = c;
    date.value = DateTime.now();
    selectedHours.clear();
    selectedDuration.value = 1;
    draft = null;
    _bookedSlots.clear();
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
  double get totalAmount => (court.value?.pricePerHour ?? 0) * totalHours;
  double get depositAmount =>
      totalAmount * BookingSettings.depositPercent / 100;
  double get remainingAmount => totalAmount - depositAmount;

  void buildDraft() {
    final a = arena.value!;
    final c = court.value!;
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
    );
  }

  // Returns picked file or null if user cancelled
  Future<XFile?> pickDepositScreenshot() =>
      _picker.pickImage(source: ImageSource.gallery);

  Future<String> submitDeposit(File screenshot, String accountUsed) async {
    final b = draft!;
    final bookingId = await _service.createBooking(b);
    await _service.submitDeposit(
      bookingId,
      screenshot: screenshot,
      accountUsed: accountUsed,
    );
    draft = null;
    selectedHours.clear();
    return bookingId;
  }

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
    super.onClose();
  }
}
