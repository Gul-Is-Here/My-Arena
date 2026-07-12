import 'package:get/get.dart';

import '../data/dummy_data.dart';
import '../data/models/arena_model.dart';
import '../data/models/booking_model.dart';
import '../data/models/court_model.dart';

enum SlotStatus { available, booked, pending, past }

/// Drives the Phase 3 booking flow. In-memory for the UI-first phase;
/// swapped for a Firestore repository (with transaction-based double
/// booking prevention) in the backend phase.
class BookingController extends GetxController {
  // ── My bookings ────────────────────────────────────────────────────
  final RxList<BookingModel> bookings = <BookingModel>[].obs;

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

  // ── Draft state for the current flow ──────────────────────────────
  final Rxn<ArenaModel> arena = Rxn<ArenaModel>();
  final Rxn<CourtModel> court = Rxn<CourtModel>();
  final Rx<DateTime> date = DateTime.now().obs;
  final RxSet<int> selectedHours = <int>{}.obs;

  BookingModel? draft;

  @override
  void onInit() {
    super.onInit();
    _seed();
  }

  void startFlow(ArenaModel a, CourtModel c) {
    arena.value = a;
    court.value = c;
    date.value = DateTime.now();
    selectedHours.clear();
    draft = null;
  }

  void selectCourt(CourtModel c) {
    court.value = c;
    selectedHours.clear();
  }

  void selectDate(DateTime d) {
    date.value = d;
    selectedHours.clear();
  }

  /// Hour slots the court operates, in display order.
  /// Handles closing past midnight (e.g. 09:00 – 02:00).
  List<int> hoursFor(CourtModel c) {
    final start = int.parse(c.startTime.split(':').first);
    var end = int.parse(c.endTime.split(':').first);
    if (end <= start) end += 24;
    return [for (var h = start; h < end; h++) h];
  }

  SlotStatus slotStatus(int hour) {
    final d = date.value;
    final slotStart = DateTime(d.year, d.month, d.day, hour);
    if (slotStart.isBefore(DateTime.now())) return SlotStatus.past;

    for (final b in bookings) {
      if (b.courtId != court.value?.id || b.isCancelled) continue;
      final hourStart = slotStart;
      final hourEnd = slotStart.add(const Duration(hours: 1));
      final overlaps =
          hourStart.isBefore(b.endDateTime) && hourEnd.isAfter(b.startDateTime);
      if (!overlaps) continue;
      return b.status == BookingStatus.confirmed ||
              b.status == BookingStatus.completed
          ? SlotStatus.booked
          : SlotStatus.pending;
    }
    return SlotStatus.available;
  }

  /// Toggle an hour keeping the selection contiguous — tapping a
  /// non-adjacent slot restarts the selection there.
  void toggleHour(int hour) {
    if (selectedHours.contains(hour)) {
      // Only allow trimming from either end so the block stays contiguous.
      final min = selectedHours.reduce((a, b) => a < b ? a : b);
      final max = selectedHours.reduce((a, b) => a > b ? a : b);
      if (hour == min || hour == max) {
        selectedHours.remove(hour);
      } else {
        selectedHours
          ..clear()
          ..add(hour);
      }
      return;
    }
    if (selectedHours.isEmpty ||
        selectedHours.contains(hour - 1) ||
        selectedHours.contains(hour + 1)) {
      selectedHours.add(hour);
    } else {
      selectedHours
        ..clear()
        ..add(hour);
    }
  }

  int get startHour =>
      selectedHours.isEmpty ? 0 : selectedHours.reduce((a, b) => a < b ? a : b);
  int get totalHours => selectedHours.length;
  double get totalAmount => (court.value?.pricePerHour ?? 0) * totalHours;
  double get depositAmount =>
      totalAmount * BookingSettings.depositPercent / 100;
  double get remainingAmount => totalAmount - depositAmount;

  /// Creates the draft booking from the current selection.
  void buildDraft() {
    final a = arena.value!;
    final c = court.value!;
    draft = BookingModel(
      id: 'booking-${DateTime.now().millisecondsSinceEpoch}',
      arenaId: a.id,
      arenaName: a.name,
      courtId: c.id,
      courtName: c.name,
      date: DateTime(date.value.year, date.value.month, date.value.day),
      startHour: startHour,
      totalHours: totalHours,
      pricePerHour: c.pricePerHour,
      createdAt: DateTime.now(),
    );
  }

  /// Deposit screenshot "uploaded" → booking submitted for approval.
  BookingModel submitDeposit() {
    final b = draft!.copyWith(
      status: BookingStatus.depositSubmitted,
      depositScreenshot: 'mock-screenshot.png',
    );
    bookings.add(b);
    draft = null;
    selectedHours.clear();
    return b;
  }

  void cancelBooking(String id, String bankName, String accountNumber) {
    final i = bookings.indexWhere((b) => b.id == id);
    if (i == -1) return;
    final b = bookings[i];
    final refund = b.depositAmount *
        (100 - BookingSettings.cancellationDeductPercent) /
        100;
    bookings[i] = b.copyWith(
      status: BookingStatus.refundPending,
      cancellation: CancellationInfo(
        requestedAt: DateTime.now(),
        refundAmount: refund,
        bankName: bankName,
        accountNumber: accountNumber,
      ),
    );
  }

  void _seed() {
    final now = DateTime.now();
    bookings.addAll([
      BookingModel(
        id: 'booking-seed-1',
        arenaId: 'arena-1',
        arenaName: 'Champions Arena',
        courtId: 'court-1',
        courtName: 'Padel Court A',
        date: DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 2)),
        startHour: 18,
        totalHours: 2,
        pricePerHour: 3000,
        status: BookingStatus.confirmed,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      BookingModel(
        id: 'booking-seed-2',
        arenaId: 'arena-3',
        arenaName: 'Padel Pro Center',
        courtId: 'court-4',
        courtName: 'Panorama Court 1',
        date: DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 5)),
        startHour: 20,
        totalHours: 1,
        pricePerHour: 3500,
        status: BookingStatus.completed,
        createdAt: now.subtract(const Duration(days: 6)),
      ),
      BookingModel(
        id: 'booking-seed-3',
        arenaId: 'arena-5',
        arenaName: 'Smash Indoor Sports',
        courtId: 'court-7',
        courtName: 'Indoor Court 1',
        date: DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 12)),
        startHour: 16,
        totalHours: 2,
        pricePerHour: 1800,
        status: BookingStatus.refundConfirmed,
        cancellation: CancellationInfo(
          requestedAt: now.subtract(const Duration(days: 13)),
          refundAmount: 864,
          bankName: 'HBL',
          accountNumber: '01234567890',
        ),
        createdAt: now.subtract(const Duration(days: 14)),
      ),
    ]);
  }

  static String get jazzCashNumber => DummyData.jazzCashNumber;
}
