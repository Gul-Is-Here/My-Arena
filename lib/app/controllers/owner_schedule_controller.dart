import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../data/models/arena_model.dart';
import '../data/models/booking_model.dart';
import '../data/models/court_model.dart';
import '../services/blocked_slot_service.dart';
import 'owner_booking_controller.dart';
import 'owner_controller.dart';

/// Owner day-schedule grid: cell statuses come from live bookings
/// (OwnerBookingController) plus the blockedSlots stream for the
/// selected arena + day.
enum ScheduleCellStatus { available, confirmed, pending, completed, blocked, past }

class OwnerScheduleController extends GetxController {
  static OwnerScheduleController get to => Get.find();

  final BlockedSlotService _blockedService = BlockedSlotService();

  final Rxn<ArenaModel> arena = Rxn<ArenaModel>();
  final Rx<DateTime> date = DateTime.now().obs;

  /// courtId → blocked hours for the selected arena + day.
  final RxMap<String, Set<int>> blocked = <String, Set<int>>{}.obs;

  StreamSubscription? _blockedSub;
  Worker? _arenasWorker;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void onInit() {
    super.onInit();
    _pickInitialArena();
    // Arena list may still be loading when the screen opens.
    _arenasWorker = ever(OwnerController.to.myArenas, (_) {
      if (arena.value == null) {
        _pickInitialArena();
      } else {
        // Keep the selected arena's courts fresh after edits.
        final updated = OwnerController.to.myArenas
            .firstWhereOrNull((a) => a.id == arena.value!.id);
        if (updated != null) arena.value = updated;
      }
    });
  }

  void _pickInitialArena() {
    final arenas = OwnerController.to.myArenas;
    if (arenas.isNotEmpty) selectArena(arenas.first);
  }

  void selectArena(ArenaModel a) {
    arena.value = a;
    _watchBlocked();
  }

  void selectDate(DateTime d) {
    date.value = DateTime(d.year, d.month, d.day);
    _watchBlocked();
  }

  void _watchBlocked() {
    _blockedSub?.cancel();
    blocked.clear();
    final a = arena.value;
    if (a == null) return;
    _blockedSub = _blockedService.watchArenaDay(a.id, date.value).listen(
      (map) => blocked.assignAll(map),
      onError: (e) => debugPrint('blockedSlots stream error: $e'),
    );
  }

  List<CourtModel> get courts =>
      arena.value?.courts.where((c) => c.isActive).toList() ?? [];

  /// Union of all courts' operating hours so the grid columns line up.
  List<int> get hours {
    var minH = 24, maxH = 0;
    for (final c in courts) {
      final s = int.tryParse(c.startTime.split(':').first) ?? 8;
      var e = int.tryParse(c.endTime.split(':').first) ?? 23;
      if (e <= s) e = 24;
      if (s < minH) minH = s;
      if (e > maxH) maxH = e;
    }
    if (minH >= maxH) return const [];
    return [for (var h = minH; h < maxH; h++) h];
  }

  bool courtOperatesAt(CourtModel c, int hour) {
    final s = int.tryParse(c.startTime.split(':').first) ?? 8;
    var e = int.tryParse(c.endTime.split(':').first) ?? 23;
    if (e <= s) e = 24;
    return hour >= s && hour < e;
  }

  List<BookingModel> _dayBookings(String courtId) {
    final a = arena.value;
    if (a == null) return const [];
    final d = date.value;
    return OwnerBookingController.to.bookings
        .where((b) =>
            b.arenaId == a.id &&
            b.courtId == courtId &&
            b.date.year == d.year &&
            b.date.month == d.month &&
            b.date.day == d.day &&
            b.status != BookingStatus.cancelled &&
            b.status != BookingStatus.rejected &&
            b.status != BookingStatus.refundPending &&
            b.status != BookingStatus.refundSent &&
            b.status != BookingStatus.refundConfirmed)
        .toList();
  }

  /// The booking occupying [hour] on [courtId], if any.
  BookingModel? bookingAt(String courtId, int hour) {
    final d = date.value;
    final slotStart = DateTime(d.year, d.month, d.day, hour);
    final slotEnd = slotStart.add(const Duration(hours: 1));
    for (final b in _dayBookings(courtId)) {
      if (slotStart.isBefore(b.endDateTime) &&
          slotEnd.isAfter(b.startDateTime)) {
        return b;
      }
    }
    return null;
  }

  ScheduleCellStatus cellStatus(String courtId, int hour) {
    final b = bookingAt(courtId, hour);
    if (b != null) {
      switch (b.status) {
        case BookingStatus.confirmed:
          return ScheduleCellStatus.confirmed;
        case BookingStatus.completed:
          return ScheduleCellStatus.completed;
        default:
          return ScheduleCellStatus.pending;
      }
    }
    if (blocked[courtId]?.contains(hour) ?? false) {
      return ScheduleCellStatus.blocked;
    }
    final d = date.value;
    final slotEnd = DateTime(d.year, d.month, d.day, hour + 1);
    if (slotEnd.isBefore(DateTime.now())) return ScheduleCellStatus.past;
    return ScheduleCellStatus.available;
  }

  /// Total operating hourly slots today across all active courts.
  int get totalSlotCount {
    var total = 0;
    for (final c in courts) {
      for (final h in hours) {
        if (courtOperatesAt(c, h)) total++;
      }
    }
    return total;
  }

  /// Slots today that are booked (confirmed, pending or completed).
  int get occupiedSlotCount {
    var occupied = 0;
    for (final c in courts) {
      for (final h in hours) {
        if (!courtOperatesAt(c, h)) continue;
        final s = cellStatus(c.id, h);
        if (s == ScheduleCellStatus.confirmed ||
            s == ScheduleCellStatus.pending ||
            s == ScheduleCellStatus.completed) {
          occupied++;
        }
      }
    }
    return occupied;
  }

  /// Fraction (0..1) of today's operating slots that are booked.
  double get occupancyRate {
    final total = totalSlotCount;
    if (total == 0) return 0;
    return occupiedSlotCount / total;
  }

  Future<void> block(CourtModel court, int hour) async {
    final a = arena.value;
    if (a == null) return;
    await _blockedService.block(
      arenaId: a.id,
      courtId: court.id,
      courtName: court.name,
      ownerId: _uid,
      date: date.value,
      hour: hour,
    );
  }

  Future<void> unblock(CourtModel court, int hour) async {
    final a = arena.value;
    if (a == null) return;
    await _blockedService.unblock(a.id, court.id, date.value, hour);
  }

  @override
  void onClose() {
    _blockedSub?.cancel();
    _arenasWorker?.dispose();
    super.onClose();
  }
}
