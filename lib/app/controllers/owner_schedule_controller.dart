import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../data/models/arena_model.dart';
import '../data/models/booking_model.dart';
import '../data/models/court_model.dart';
import '../services/arena_service.dart';
import '../services/blocked_slot_service.dart';
import 'auth_controller.dart';
import 'owner_booking_controller.dart';
import 'owner_controller.dart';

/// Owner day-schedule grid: cell statuses come from live bookings
/// (OwnerBookingController) plus the blockedSlots stream for the
/// selected arena + day.
enum ScheduleCellStatus { available, confirmed, pending, completed, blocked, past }

class OwnerScheduleController extends GetxController {
  static OwnerScheduleController get to => Get.find();

  final BlockedSlotService _blockedService = BlockedSlotService();
  final ArenaService _arenaService = ArenaService();

  final Rxn<ArenaModel> arena = Rxn<ArenaModel>();
  final Rx<DateTime> date = DateTime.now().obs;

  /// Arenas available in the selector. For owners this mirrors
  /// OwnerController.myArenas; for arena staff it's loaded from their
  /// assignedArenas list.
  final RxList<ArenaModel> arenas = <ArenaModel>[].obs;

  /// courtId → blocked hours for the selected arena + day.
  final RxMap<String, Set<int>> blocked = <String, Set<int>>{}.obs;

  StreamSubscription? _blockedSub;
  Worker? _arenasWorker;
  final Map<String, StreamSubscription> _courtSubs = {};

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void onInit() {
    super.onInit();
    final user = AuthController.to.currentUser.value;
    if (user?.isArenaStaff == true) {
      _loadStaffArenas(user!.assignedArenas);
    } else {
      // Owner path: mirror OwnerController.myArenas reactively.
      arenas.assignAll(OwnerController.to.myArenas);
      _pickInitialArena();
      _arenasWorker = ever(OwnerController.to.myArenas, (list) {
        arenas.assignAll(list);
        if (arena.value == null) {
          _pickInitialArena();
        } else {
          final updated =
              arenas.firstWhereOrNull((a) => a.id == arena.value!.id);
          if (updated != null) arena.value = updated;
        }
      });
    }
  }

  Future<void> _loadStaffArenas(List<String> ids) async {
    try {
      final loaded = await _arenaService.arenasByIds(ids);
      arenas.assignAll(loaded);
      if (loaded.isNotEmpty) selectArena(loaded.first);

      // Open a live courts-subcollection stream for each arena, matching the
      // pattern used by OwnerController. Without this, arena.courts is always
      // empty because ArenaModel.fromMap only reads the arena document — courts
      // live in a subcollection and are never embedded in the doc.
      for (final a in loaded) {
        _courtSubs[a.id]?.cancel();
        _courtSubs[a.id] = _arenaService.courts(a.id).listen((courts) {
          final idx = arenas.indexWhere((x) => x.id == a.id);
          if (idx == -1) return;
          final updated = arenas[idx].copyWith(courts: courts);
          arenas[idx] = updated;
          if (arena.value?.id == a.id) arena.value = updated;
        });
      }
    } catch (e) {
      debugPrint('OwnerScheduleController: failed to load staff arenas: $e');
    }
  }

  void _pickInitialArena() {
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
    for (final sub in _courtSubs.values) {
      sub.cancel();
    }
    super.onClose();
  }
}
