import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:get/get.dart';

import '../data/models/arena_model.dart';
import '../data/models/booking_model.dart';
import '../data/models/user_model.dart';
import '../services/arena_service.dart';

/// Date range filters shared by every report.
enum ReportRange { today, yesterday, week, month, year, custom }

extension ReportRangeX on ReportRange {
  String get label {
    switch (this) {
      case ReportRange.today:
        return 'Today';
      case ReportRange.yesterday:
        return 'Yesterday';
      case ReportRange.week:
        return 'This Week';
      case ReportRange.month:
        return 'This Month';
      case ReportRange.year:
        return 'This Year';
      case ReportRange.custom:
        return 'Custom';
    }
  }

  int get days {
    switch (this) {
      case ReportRange.today:
      case ReportRange.yesterday:
        return 1;
      case ReportRange.week:
        return 7;
      case ReportRange.month:
        return 30;
      case ReportRange.year:
        return 365;
      case ReportRange.custom:
        return 14;
    }
  }
}

/// Per-arena booking stats for the selected range.
class ArenaBookingStats {
  final ArenaModel arena;
  final int total;
  final int confirmed;
  final int cancelled;
  final int pending;
  final List<int> hourly; // 24 buckets — peak hours
  final List<double> trend; // bookings per day across the range

  const ArenaBookingStats({
    required this.arena,
    required this.total,
    required this.confirmed,
    required this.cancelled,
    required this.pending,
    required this.hourly,
    required this.trend,
  });

  int get peakHour {
    var best = 0;
    for (var h = 0; h < hourly.length; h++) {
      if (hourly[h] > hourly[best]) best = h;
    }
    return best;
  }
}

/// Per-arena revenue stats for the selected range.
class ArenaRevenueStats {
  final ArenaModel arena;
  final double total;
  final int completedBookings;
  final List<double> daily; // revenue per day across the range

  const ArenaRevenueStats({
    required this.arena,
    required this.total,
    required this.completedBookings,
    required this.daily,
  });

  double get avgBookingValue =>
      completedBookings == 0 ? 0 : total / completedBookings;
}

/// Per-staff performance stats derived from tickets assigned to them.
class StaffStats {
  final String uid;
  final String name;
  final bool isActive;
  final int handled;
  final int completed;
  final int cancelled;
  final double revenue;

  const StaffStats({
    required this.uid,
    required this.name,
    required this.isActive,
    required this.handled,
    required this.completed,
    required this.cancelled,
    required this.revenue,
  });

  double get completionRate => handled == 0 ? 0 : completed / handled;
}

/// Real analytics from Firestore — streams bookings for the selected date range
/// and computes per-arena and platform-wide stats from actual data.
class AnalyticsController extends GetxController {
  static AnalyticsController get to => Get.find();

  final _arenaService = ArenaService();
  final _db = FirebaseFirestore.instance;

  StreamSubscription? _arenaSub;
  StreamSubscription? _bookingsSub;
  StreamSubscription? _staffSub;
  StreamSubscription? _ticketsSub;

  final Rx<ReportRange> range = ReportRange.week.obs;
  final Rxn<DateTimeRange> customRange = Rxn<DateTimeRange>();
  final RxnString arenaFilter = RxnString();

  final RxList<ArenaModel> arenas = <ArenaModel>[].obs;
  final RxList<BookingModel> _bookings = <BookingModel>[].obs;
  final RxList<UserModel> _staffUsers = <UserModel>[].obs;

  // ticket counts per staff uid: {'uid': {'total': n, 'resolved': n}}
  final RxMap<String, Map<String, int>> _ticketCounts =
      <String, Map<String, int>>{}.obs;

  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _arenaSub = _arenaService.allArenas().listen((list) => arenas.assignAll(list));
    _staffSub = _db
        .collection('users')
        .where('role', whereIn: ['staff', 'supportAgent'])
        .snapshots()
        .listen((s) => _staffUsers.assignAll(
              s.docs.map((d) => UserModel.fromMap({...d.data(), 'uid': d.id})).toList(),
            ));
    ever(range, (_) => _refreshBookings());
    ever(customRange, (_) => _refreshBookings());
    _refreshBookings();
    _refreshTickets();
  }

  @override
  void onClose() {
    _arenaSub?.cancel();
    _bookingsSub?.cancel();
    _staffSub?.cancel();
    _ticketsSub?.cancel();
    super.onClose();
  }

  // ── Date range helpers ─────────────────────────────────────────────────

  int get _days {
    if (range.value == ReportRange.custom && customRange.value != null) {
      return customRange.value!.duration.inDays + 1;
    }
    return range.value.days;
  }

  DateTime get _rangeStart {
    if (range.value == ReportRange.custom && customRange.value != null) {
      return customRange.value!.start;
    }
    final now = DateTime.now();
    if (range.value == ReportRange.yesterday) {
      return DateTime(now.year, now.month, now.day - 1);
    }
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: _days - 1));
  }

  DateTime get _rangeEnd {
    if (range.value == ReportRange.custom && customRange.value != null) {
      return customRange.value!.end;
    }
    if (range.value == ReportRange.yesterday) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
    }
    return DateTime.now();
  }

  String get rangeLabel {
    if (range.value == ReportRange.custom && customRange.value != null) {
      final r = customRange.value!;
      String f(DateTime d) => '${d.day}/${d.month}';
      return '${f(r.start)} – ${f(r.end)}';
    }
    return range.value.label;
  }

  // ── Streams ────────────────────────────────────────────────────────────

  void _refreshBookings() {
    isLoading.value = true;
    _bookingsSub?.cancel();
    final from = Timestamp.fromDate(_rangeStart);
    final to = Timestamp.fromDate(_rangeEnd);
    _bookingsSub = _db
        .collection('bookings')
        .where('date', isGreaterThanOrEqualTo: from)
        .where('date', isLessThanOrEqualTo: to)
        .snapshots()
        .listen((s) {
      _bookings.assignAll(
        s.docs.map((d) => BookingModel.fromMap({...d.data(), 'id': d.id})).toList(),
      );
      isLoading.value = false;
    }, onError: (_) => isLoading.value = false);
  }

  void _refreshTickets() {
    _ticketsSub?.cancel();
    _ticketsSub = _db.collection('tickets').snapshots().listen((s) {
      final counts = <String, Map<String, int>>{};
      for (final doc in s.docs) {
        final data = doc.data();
        final uid = (data['assignedTo'] as String?) ?? '';
        if (uid.isEmpty) continue;
        counts.putIfAbsent(uid, () => {'total': 0, 'resolved': 0});
        counts[uid]!['total'] = (counts[uid]!['total'] ?? 0) + 1;
        if ((data['status'] as String?) == 'resolved') {
          counts[uid]!['resolved'] = (counts[uid]!['resolved'] ?? 0) + 1;
        }
      }
      _ticketCounts.assignAll(counts);
    });
  }

  // ── Derived stats ──────────────────────────────────────────────────────

  List<BookingModel> get _filtered {
    final id = arenaFilter.value;
    return id == null ? _bookings : _bookings.where((b) => b.arenaId == id).toList();
  }

  List<ArenaBookingStats> get bookingStats {
    final filtered = _filtered;
    final arenaList = arenaFilter.value == null
        ? arenas.toList()
        : arenas.where((a) => a.id == arenaFilter.value).toList();
    final days = _days;
    final start = _rangeStart;

    return arenaList.map((arena) {
      final ab = filtered.where((b) => b.arenaId == arena.id).toList();
      final confirmed = ab.where((b) => b.status == BookingStatus.confirmed).length;
      final cancelled = ab.where((b) => b.isCancelled).length;
      final pending = ab.where((b) => b.status == BookingStatus.pendingDeposit || b.status == BookingStatus.depositSubmitted).length;

      // hourly buckets from startHour field
      final hourly = List<int>.filled(24, 0);
      for (final b in ab) {
        final h = b.startHour;
        if (h >= 0 && h < 24) hourly[h]++;
      }

      // trend: bookings per day
      final trend = List<double>.filled(days, 0);
      for (final b in ab) {
        final diff = b.date.difference(start).inDays;
        if (diff >= 0 && diff < days) trend[diff]++;
      }

      return ArenaBookingStats(
        arena: arena,
        total: ab.length,
        confirmed: confirmed,
        cancelled: cancelled,
        pending: pending,
        hourly: hourly,
        trend: trend,
      );
    }).toList();
  }

  List<ArenaRevenueStats> get revenueStats {
    final filtered = _filtered;
    final arenaList = arenaFilter.value == null
        ? arenas.toList()
        : arenas.where((a) => a.id == arenaFilter.value).toList();
    final days = _days;
    final start = _rangeStart;

    return arenaList.map((arena) {
      final ab = filtered
          .where((b) => b.arenaId == arena.id && b.status == BookingStatus.completed)
          .toList();
      final daily = List<double>.filled(days, 0);
      for (final b in ab) {
        final diff = b.date.difference(start).inDays;
        if (diff >= 0 && diff < days) daily[diff] += b.totalAmount;
      }
      final total = daily.fold<double>(0, (s, v) => s + v);
      return ArenaRevenueStats(
        arena: arena,
        total: total,
        completedBookings: ab.length,
        daily: daily,
      );
    }).toList();
  }

  double get totalRevenue => revenueStats.fold(0, (sum, r) => sum + r.total);

  List<StaffStats> get staffStats {
    return _staffUsers.map((u) {
      final counts = _ticketCounts[u.uid] ?? {'total': 0, 'resolved': 0};
      final handled = counts['total'] ?? 0;
      final resolved = counts['resolved'] ?? 0;
      return StaffStats(
        uid: u.uid,
        name: u.name,
        isActive: u.isActive,
        handled: handled,
        completed: resolved,
        cancelled: 0,
        revenue: 0,
      );
    }).toList();
  }
}
