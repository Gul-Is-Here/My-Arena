import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../data/models/arena_model.dart';
import '../data/models/booking_model.dart';
import '../data/models/court_model.dart';
import '../services/arena_service.dart';

enum RevenueRange { daily, weekly, monthly }

class OwnerController extends GetxController {
  static OwnerController get to => Get.find();

  final ArenaService _arenaService = ArenaService();

  final RxList<ArenaModel> myArenas = <ArenaModel>[].obs;
  final Rx<RevenueRange> revenueRange = RevenueRange.daily.obs;
  final RxBool isLoading = true.obs;

  // Live booking stats from Firestore
  final RxInt totalBookings = 0.obs;
  final RxDouble totalEarnings = 0.0.obs;
  final RxInt pendingDeposits = 0.obs;

  StreamSubscription? _arenaSub;
  StreamSubscription? _bookingsSub;

  String get _uid => AuthController.to.currentUser.value?.uid ?? '';

  @override
  void onInit() {
    super.onInit();
    _listenArenas();
    _listenBookingStats();
  }

  void _listenArenas() {
    _arenaSub?.cancel();
    if (_uid.isEmpty) return;
    isLoading.value = true;
    _arenaSub = _arenaService.ownerArenas(_uid).listen((arenas) async {
      // Fetch courts for each arena
      final enriched = <ArenaModel>[];
      for (final arena in arenas) {
        final courtsSnap = await FirebaseFirestore.instance
            .collection('arenas')
            .doc(arena.id)
            .collection('courts')
            .get();
        final courts = courtsSnap.docs
            .map((d) => CourtModel.fromMap({...d.data(), 'id': d.id}))
            .toList();
        enriched.add(arena.copyWith(courts: courts));
      }
      myArenas.assignAll(enriched);
      isLoading.value = false;
    }, onError: (_) => isLoading.value = false);
  }

  void _listenBookingStats() {
    if (_uid.isEmpty) return;
    final arenaIds = myArenas.map((a) => a.id).toList();
    if (arenaIds.isEmpty) {
      ever(myArenas, (_) {
        if (myArenas.isNotEmpty) _listenBookingStats();
      });
      return;
    }
    _bookingsSub?.cancel();
    _bookingsSub = FirebaseFirestore.instance
        .collection('bookings')
        .where('ownerId', isEqualTo: _uid)
        .snapshots()
        .listen((snap) {
      totalBookings.value = snap.docs.length;
      totalEarnings.value = snap.docs.fold(0.0, (acc, d) {
        final data = d.data();
        if (data['status'] == 'confirmed' || data['status'] == 'completed') {
          return acc + ((data['totalAmount'] ?? 0) as num).toDouble();
        }
        return acc;
      });
      pendingDeposits.value = snap.docs
          .where((d) => d.data()['status'] == 'deposit_submitted')
          .length;
    });
  }

  int get activeCourts =>
      myArenas.fold(0, (acc, a) => acc + a.courts.where((c) => c.isActive).length);

  int get pendingApprovals =>
      myArenas.where((a) => a.status == ArenaStatus.pending).length;

  List<double> revenuePoints(List<BookingModel> bookings) {
    final paid = bookings.where((b) =>
        b.status == BookingStatus.confirmed ||
        b.status == BookingStatus.completed).toList();
    final now = DateTime.now();
    switch (revenueRange.value) {
      case RevenueRange.daily:
        return List.generate(7, (i) {
          final day = now.subtract(Duration(days: 6 - i));
          return paid
              .where((b) =>
                  b.date.year == day.year &&
                  b.date.month == day.month &&
                  b.date.day == day.day)
              .fold(0.0, (acc, b) => acc + b.totalAmount);
        });
      case RevenueRange.weekly:
        final todayMon = now.subtract(Duration(days: now.weekday - 1));
        final monDate = DateTime(todayMon.year, todayMon.month, todayMon.day);
        return List.generate(4, (i) {
          final weekStart = monDate.subtract(Duration(days: (3 - i) * 7));
          final weekEnd = weekStart.add(const Duration(days: 7));
          return paid
              .where((b) {
                final d = DateTime(b.date.year, b.date.month, b.date.day);
                return !d.isBefore(weekStart) && d.isBefore(weekEnd);
              })
              .fold(0.0, (acc, b) => acc + b.totalAmount);
        });
      case RevenueRange.monthly:
        return List.generate(6, (i) {
          int m = now.month - (5 - i);
          int y = now.year;
          if (m <= 0) { m += 12; y -= 1; }
          return paid
              .where((b) => b.date.year == y && b.date.month == m)
              .fold(0.0, (acc, b) => acc + b.totalAmount);
        });
    }
  }

  List<String> get revenueLabels {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    switch (revenueRange.value) {
      case RevenueRange.daily:
        return List.generate(7, (i) =>
            days[now.subtract(Duration(days: 6 - i)).weekday - 1]);
      case RevenueRange.weekly:
        return ['W1', 'W2', 'W3', 'W4'];
      case RevenueRange.monthly:
        return List.generate(6, (i) {
          int m = now.month - (5 - i);
          if (m <= 0) m += 12;
          return months[m - 1];
        });
    }
  }

  Future<void> toggleArenaActive(String arenaId) async {
    final index = myArenas.indexWhere((a) => a.id == arenaId);
    if (index == -1) return;
    final current = myArenas[index].isActive;
    myArenas[index] = myArenas[index].copyWith(isActive: !current);
    myArenas.refresh();
    try {
      await _arenaService.toggleActive(arenaId, !current);
    } catch (_) {
      // revert on failure
      myArenas[index] = myArenas[index].copyWith(isActive: current);
      myArenas.refresh();
    }
  }

  Future<void> toggleCourtActive(String arenaId, String courtId) async {
    final arenaIndex = myArenas.indexWhere((a) => a.id == arenaId);
    if (arenaIndex == -1) return;
    final arena = myArenas[arenaIndex];
    final courtIndex = arena.courts.indexWhere((c) => c.id == courtId);
    if (courtIndex == -1) return;
    final current = arena.courts[courtIndex].isActive;
    final courts = [...arena.courts];
    courts[courtIndex] = courts[courtIndex].copyWith(isActive: !current);
    myArenas[arenaIndex] = arena.copyWith(courts: courts);
    myArenas.refresh();
    try {
      await _arenaService.updateCourt(arenaId, courtId, {'isActive': !current});
    } catch (_) {
      final reverted = [...arena.courts];
      reverted[courtIndex] = reverted[courtIndex].copyWith(isActive: current);
      myArenas[arenaIndex] = arena.copyWith(courts: reverted);
      myArenas.refresh();
    }
  }

  Future<void> deleteArena(String arenaId) async {
    await _arenaService.deleteArena(arenaId);
    myArenas.removeWhere((a) => a.id == arenaId);
  }

  @override
  void onClose() {
    _arenaSub?.cancel();
    _bookingsSub?.cancel();
    super.onClose();
  }
}
