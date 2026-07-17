import 'dart:async';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:get/get.dart';

import '../data/models/arena_model.dart';
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
        return 14; // replaced by the picked range length
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

/// Per-staff performance stats.
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

/// Deterministic pseudo-analytics using real arena list from Firestore.
/// Real aggregation stats require Cloud Functions or Firestore queries.
class AnalyticsController extends GetxController {
  static AnalyticsController get to => Get.find();

  final _arenaService = ArenaService();
  StreamSubscription? _arenaSub;

  final Rx<ReportRange> range = ReportRange.week.obs;
  final Rxn<DateTimeRange> customRange = Rxn<DateTimeRange>();

  /// null = all arenas.
  final RxnString arenaFilter = RxnString();

  final RxList<ArenaModel> arenas = <ArenaModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    _arenaSub = _arenaService.allArenas().listen((list) => arenas.assignAll(list));
  }

  @override
  void onClose() {
    _arenaSub?.cancel();
    super.onClose();
  }

  int get _days {
    if (range.value == ReportRange.custom && customRange.value != null) {
      return customRange.value!.duration.inDays + 1;
    }
    return range.value.days;
  }

  String get rangeLabel {
    if (range.value == ReportRange.custom && customRange.value != null) {
      final r = customRange.value!;
      String f(DateTime d) => '${d.day}/${d.month}';
      return '${f(r.start)} – ${f(r.end)}';
    }
    return range.value.label;
  }

  // Deterministic pseudo-random stream from a seed.
  int _next(int state) => (state * 1103515245 + 12345) & 0x7fffffff;

  List<ArenaBookingStats> get bookingStats {
    final list = arenaFilter.value == null
        ? arenas
        : arenas.where((a) => a.id == arenaFilter.value).toList();
    return list.map((a) {
      var s = a.id.hashCode ^ range.value.index ^ _days;
      final days = _days;
      final trend = <double>[];
      var total = 0;
      for (var d = 0; d < days; d++) {
        s = _next(s);
        final v = 2 + s % 9;
        trend.add(v.toDouble());
        total += v;
      }
      final hourly = List<int>.filled(24, 0);
      var remaining = total;
      // Bias bookings toward evenings (17:00–23:00).
      for (var h = 0; h < 24 && remaining > 0; h++) {
        s = _next(s);
        final weight = (h >= 17 && h <= 23) ? 4 : (h >= 9 ? 1 : 0);
        final v = weight == 0 ? 0 : (s % (weight * 3)).clamp(0, remaining);
        hourly[h] = v;
        remaining -= v;
      }
      hourly[19] += remaining.clamp(0, 1 << 30);
      s = _next(s);
      final cancelled = (total * (5 + s % 10) / 100).round();
      s = _next(s);
      final pending = (total * (5 + s % 8) / 100).round();
      return ArenaBookingStats(
        arena: a,
        total: total,
        confirmed: total - cancelled - pending,
        cancelled: cancelled,
        pending: pending,
        hourly: hourly,
        trend: trend,
      );
    }).toList();
  }

  List<ArenaRevenueStats> get revenueStats {
    return bookingStats.map((b) {
      final price = b.arena.minPrice == 0 ? 2000.0 : b.arena.minPrice;
      final daily = b.trend.map((v) => v * price * 1.6).toList();
      final total = daily.fold<double>(0, (sum, v) => sum + v);
      return ArenaRevenueStats(
        arena: b.arena,
        total: total,
        completedBookings: b.confirmed,
        daily: daily,
      );
    }).toList();
  }

  double get totalRevenue =>
      revenueStats.fold(0, (sum, r) => sum + r.total);

  List<StaffStats> get staffStats {
    const staff = [
      ('u5', 'Bilal Ahmed', true),
      ('u6', 'Ayesha Tariq', true),
      ('u7', 'Danish Iqbal', false),
    ];
    return staff.map((entry) {
      final (uid, name, active) = entry;
      var s = uid.hashCode ^ range.value.index ^ _days;
      s = _next(s);
      final handled = 5 * _days + s % (10 * _days + 1);
      s = _next(s);
      final cancelled = (handled * (4 + s % 8) / 100).round();
      s = _next(s);
      final completed = handled - cancelled - s % (handled ~/ 5 + 1);
      s = _next(s);
      final revenue = completed * (1800 + (s % 12) * 100).toDouble();
      return StaffStats(
        uid: uid,
        name: name,
        isActive: active,
        handled: handled,
        completed: completed,
        cancelled: cancelled,
        revenue: revenue,
      );
    }).toList();
  }
}
