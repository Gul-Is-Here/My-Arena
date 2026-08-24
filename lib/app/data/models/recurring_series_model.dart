import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: recurringBookingSeries/{seriesId}
///
/// One document per recurring booking series. Individual occurrences live in
/// bookings/{bookingId} and reference this doc via recurringGroupId == seriesId.
/// The series doc is the authoritative source of series-level state so owners
/// and customers can query it without aggregating individual occurrences.

enum SeriesStatus {
  pending,
  confirmed,
  partiallyConfirmed,
  cancelled,
  completed,
  expired,
}

extension SeriesStatusX on SeriesStatus {
  String get key {
    switch (this) {
      case SeriesStatus.pending:
        return 'pending';
      case SeriesStatus.confirmed:
        return 'confirmed';
      case SeriesStatus.partiallyConfirmed:
        return 'partially_confirmed';
      case SeriesStatus.cancelled:
        return 'cancelled';
      case SeriesStatus.completed:
        return 'completed';
      case SeriesStatus.expired:
        return 'expired';
    }
  }

  String get label {
    switch (this) {
      case SeriesStatus.pending:
        return 'Pending Approval';
      case SeriesStatus.confirmed:
        return 'Confirmed';
      case SeriesStatus.partiallyConfirmed:
        return 'Partially Confirmed';
      case SeriesStatus.cancelled:
        return 'Cancelled';
      case SeriesStatus.completed:
        return 'Completed';
      case SeriesStatus.expired:
        return 'Expired';
    }
  }

  bool get isActive =>
      this == SeriesStatus.pending ||
      this == SeriesStatus.confirmed ||
      this == SeriesStatus.partiallyConfirmed;
}

class RecurringSeriesModel {
  final String id;
  final String customerId;
  final String customerName;
  final String arenaId;
  final String arenaName;
  final String courtId;
  final String courtName;
  final String ownerId;

  /// Always 'weekly' for now; future-proofed for bi-weekly / monthly.
  final String frequency;

  final DateTime startDate;
  final DateTime endDate;
  final int totalOccurrences;
  final SeriesStatus status;

  /// Shared deposit screenshot URL (same file uploaded once for all weeks).
  final String? depositScreenshotUrl;

  final DateTime createdAt;
  final DateTime? confirmedAt;

  /// How many occurrences are currently confirmed.
  final int confirmedCount;

  final int startHour;
  final int totalHours;

  /// ID of the first occurrence — used to navigate into the series from owner UI.
  final String? firstBookingId;

  const RecurringSeriesModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.arenaId,
    required this.arenaName,
    required this.courtId,
    required this.courtName,
    required this.ownerId,
    this.frequency = 'weekly',
    required this.startDate,
    required this.endDate,
    required this.totalOccurrences,
    required this.status,
    required this.createdAt,
    this.depositScreenshotUrl,
    this.confirmedAt,
    this.confirmedCount = 0,
    required this.startHour,
    required this.totalHours,
    this.firstBookingId,
  });

  String get timeRange {
    String fmt(int h) => '${(h % 24).toString().padLeft(2, '0')}:00';
    return '${fmt(startHour)} – ${fmt(startHour + totalHours)}';
  }

  bool get isFullyConfirmed =>
      confirmedCount == totalOccurrences && confirmedCount > 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerId': customerId,
        'customerName': customerName,
        'arenaId': arenaId,
        'arenaName': arenaName,
        'courtId': courtId,
        'courtName': courtName,
        'ownerId': ownerId,
        'frequency': frequency,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'totalOccurrences': totalOccurrences,
        'status': status.key,
        'confirmedCount': confirmedCount,
        'startHour': startHour,
        'totalHours': totalHours,
        if (depositScreenshotUrl != null)
          'depositScreenshotUrl': depositScreenshotUrl,
        if (firstBookingId != null) 'firstBookingId': firstBookingId,
      };

  factory RecurringSeriesModel.fromMap(Map<String, dynamic> m) =>
      RecurringSeriesModel(
        id: m['id'] as String? ?? '',
        customerId: m['customerId'] as String? ?? '',
        customerName: m['customerName'] as String? ?? '',
        arenaId: m['arenaId'] as String? ?? '',
        arenaName: m['arenaName'] as String? ?? '',
        courtId: m['courtId'] as String? ?? '',
        courtName: m['courtName'] as String? ?? '',
        ownerId: m['ownerId'] as String? ?? '',
        frequency: m['frequency'] as String? ?? 'weekly',
        startDate: (m['startDate'] as dynamic)?.toDate() ?? DateTime.now(),
        endDate: (m['endDate'] as dynamic)?.toDate() ?? DateTime.now(),
        totalOccurrences: (m['totalOccurrences'] as int?) ?? 0,
        status: SeriesStatus.values.firstWhere(
          (s) => s.key == m['status'],
          orElse: () => SeriesStatus.pending,
        ),
        createdAt:
            (m['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
        depositScreenshotUrl: m['depositScreenshotUrl'] as String?,
        confirmedAt: m['confirmedAt'] != null
            ? (m['confirmedAt'] as dynamic).toDate()
            : null,
        confirmedCount: (m['confirmedCount'] as int?) ?? 0,
        startHour: (m['startHour'] as int?) ?? 0,
        totalHours: (m['totalHours'] as int?) ?? 1,
        firstBookingId: m['firstBookingId'] as String?,
      );
}
