import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors Firestore bookings/{bookingId} from scope.md.
enum BookingStatus {
  pendingDeposit,
  depositSubmitted,
  confirmed,
  ongoing,
  rejected,
  completed,
  cancelled,
  refundPending,
  refundSent,
  refundConfirmed,
  rescheduleRequested,
}

extension BookingStatusX on BookingStatus {
  String get key {
    switch (this) {
      case BookingStatus.pendingDeposit:
        return 'pending_deposit';
      case BookingStatus.depositSubmitted:
        return 'deposit_submitted';
      case BookingStatus.confirmed:
        return 'confirmed';
      case BookingStatus.ongoing:
        return 'ongoing';
      case BookingStatus.rejected:
        return 'rejected';
      case BookingStatus.completed:
        return 'completed';
      case BookingStatus.cancelled:
        return 'cancelled';
      case BookingStatus.refundPending:
        return 'refund_pending';
      case BookingStatus.refundSent:
        return 'refund_sent';
      case BookingStatus.refundConfirmed:
        return 'refund_confirmed';
      case BookingStatus.rescheduleRequested:
        return 'reschedule_requested';
    }
  }

  String get label {
    switch (this) {
      case BookingStatus.pendingDeposit:
        return 'Deposit Pending';
      case BookingStatus.depositSubmitted:
        return 'Deposit Submitted';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.ongoing:
        return 'Ongoing';
      case BookingStatus.rejected:
        return 'Rejected';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.refundPending:
        return 'Refund Pending';
      case BookingStatus.refundSent:
        return 'Refund Sent';
      case BookingStatus.refundConfirmed:
        return 'Refund Confirmed';
      case BookingStatus.rescheduleRequested:
        return 'Reschedule Requested';
    }
  }
}

class RescheduleRequest {
  final DateTime proposedDate;
  final int proposedStartHour;
  final int proposedTotalHours;
  final DateTime requestedAt;

  const RescheduleRequest({
    required this.proposedDate,
    required this.proposedStartHour,
    required this.proposedTotalHours,
    required this.requestedAt,
  });

  Map<String, dynamic> toMap() => {
        'proposedDate': Timestamp.fromDate(proposedDate),
        'proposedStartHour': proposedStartHour,
        'proposedTotalHours': proposedTotalHours,
        'requestedAt': Timestamp.fromDate(requestedAt),
      };

  factory RescheduleRequest.fromMap(Map<String, dynamic> m) => RescheduleRequest(
        proposedDate: (m['proposedDate'] as dynamic).toDate(),
        proposedStartHour: (m['proposedStartHour'] ?? 0) as int,
        proposedTotalHours: (m['proposedTotalHours'] ?? 1) as int,
        requestedAt: m['requestedAt'] != null
            ? (m['requestedAt'] as dynamic).toDate()
            : DateTime.now(),
      );

  String get timeRange {
    final end = proposedStartHour + proposedTotalHours;
    String fmt(int h) => '${h.toString().padLeft(2, '0')}:00';
    return '${fmt(proposedStartHour)} – ${fmt(end)}';
  }
}

/// Mirrors Firestore settings/booking. Static for the UI-first phase;
/// admin-editable once the backend lands.
class BookingSettings {
  BookingSettings._();

  static const int depositPercent = 30;
  static const int cancellationDeductPercent = 20;
  static const int minCancelHoursBefore = 1;
}

class CancellationInfo {
  final DateTime requestedAt;
  final int deductionPercent;
  final double refundAmount;
  final String bankName;
  final String accountNumber;

  const CancellationInfo({
    required this.requestedAt,
    this.deductionPercent = BookingSettings.cancellationDeductPercent,
    required this.refundAmount,
    this.bankName = '',
    this.accountNumber = '',
  });
}

class BookingModel {
  final String id;
  final String arenaId;
  final String arenaName;
  final String courtId;
  final String courtName;
  final String customerName;
  final String customerId;
  final String ownerId;
  final String bookedByRole; // 'customer' | 'owner' | 'staff'
  final DateTime date;
  final int startHour; // 0–23, slot start
  final int totalHours;
  final double pricePerHour;
  final BookingStatus status;
  final String? depositScreenshot;
  final CancellationInfo? cancellation;
  final DateTime createdAt;
  final bool checkedIn;
  final DateTime? checkedInAt;
  final bool hasReview;

  /// Set when the booking auto-completed without a check-in — the
  /// customer never showed up.
  final bool noShow;

  /// When peak-hour pricing applies, the controller stores the correct sum
  /// here instead of relying on the flat pricePerHour * totalHours formula.
  final double? totalAmountStored;

  final RescheduleRequest? rescheduleRequest;

  // ── Recurring ─────────────────────────────────────────────────────────
  /// UUID shared by all bookings in the same recurring series.
  final String? recurringGroupId;
  /// 1-based index of this booking within its series (e.g. 2 of 8).
  final int? recurringWeek;
  /// Total number of weeks in the series (e.g. 8).
  final int? recurringTotal;

  // ── Group booking ─────────────────────────────────────────────────────
  final bool isGroupBooking;
  /// Total number of players sharing the slot.
  final int groupSize;
  /// 6-char alphanumeric code that others use to join this group booking.
  final String? joinCode;

  const BookingModel({
    required this.id,
    required this.arenaId,
    required this.arenaName,
    required this.courtId,
    required this.courtName,
    this.customerId = '',
    this.ownerId = '',
    this.customerName = '',
    this.bookedByRole = 'customer',
    required this.date,
    required this.startHour,
    required this.totalHours,
    required this.pricePerHour,
    this.status = BookingStatus.pendingDeposit,
    this.depositScreenshot,
    this.cancellation,
    required this.createdAt,
    this.checkedIn = false,
    this.checkedInAt,
    this.hasReview = false,
    this.noShow = false,
    this.totalAmountStored,
    this.rescheduleRequest,
    this.recurringGroupId,
    this.recurringWeek,
    this.recurringTotal,
    this.isGroupBooking = false,
    this.groupSize = 1,
    this.joinCode,
  });

  double get totalAmount => totalAmountStored ?? pricePerHour * totalHours;
  double get depositAmount =>
      totalAmount * BookingSettings.depositPercent / 100;
  double get remainingAmount => totalAmount - depositAmount;

  DateTime get startDateTime =>
      DateTime(date.year, date.month, date.day, startHour);
  DateTime get endDateTime =>
      startDateTime.add(Duration(hours: totalHours));

  int get endHour => (startHour + totalHours) % 24;

  String get timeRange =>
      '${_fmtHour(startHour)} – ${_fmtHour(startHour + totalHours)}';

  static String _fmtHour(int h) =>
      '${(h % 24).toString().padLeft(2, '0')}:00';

  bool get isActive => status == BookingStatus.ongoing;

  String get displayLabel => isActive ? 'Ongoing' : status.label;

  bool get isUpcoming =>
      endDateTime.isAfter(DateTime.now()) &&
      status != BookingStatus.cancelled &&
      status != BookingStatus.rejected &&
      status != BookingStatus.refundPending &&
      status != BookingStatus.refundSent &&
      status != BookingStatus.refundConfirmed;

  bool get isCancelled =>
      status == BookingStatus.cancelled ||
      status == BookingStatus.rejected ||
      status == BookingStatus.refundPending ||
      status == BookingStatus.refundSent ||
      status == BookingStatus.refundConfirmed;

  bool get canReschedule =>
      (status == BookingStatus.confirmed ||
          status == BookingStatus.depositSubmitted) &&
      startDateTime.difference(DateTime.now()).inHours >= 24;

  bool get canCancel =>
      isUpcoming &&
      startDateTime.difference(DateTime.now()).inMinutes >=
          BookingSettings.minCancelHoursBefore * 60;

  String get startTime => '${startHour.toString().padLeft(2, '0')}:00';
  String get endTime =>
      '${((startHour + totalHours) % 24).toString().padLeft(2, '0')}:00';

  Map<String, dynamic> toMap() => {
        'id': id,
        'arenaId': arenaId,
        'arenaName': arenaName,
        'courtId': courtId,
        'courtName': courtName,
        'customerName': customerName,
        'customerId': customerId,
        'ownerId': ownerId,
        'bookedByRole': bookedByRole,
        'date': Timestamp.fromDate(date),
        'startHour': startHour,
        'totalHours': totalHours,
        'pricePerHour': pricePerHour,
        'startTime': startTime,
        'endTime': endTime,
        'status': status.key,
        if (totalAmountStored != null) 'totalAmount': totalAmountStored,
        if (recurringGroupId != null) 'recurringGroupId': recurringGroupId,
        if (recurringWeek != null) 'recurringWeek': recurringWeek,
        if (recurringTotal != null) 'recurringTotal': recurringTotal,
        if (isGroupBooking) 'isGroupBooking': true,
        if (isGroupBooking) 'groupSize': groupSize,
        if (joinCode != null) 'joinCode': joinCode,
      };

  factory BookingModel.fromMap(Map<String, dynamic> m) => BookingModel(
        id: m['id'] ?? '',
        arenaId: m['arenaId'] ?? '',
        arenaName: m['arenaName'] ?? '',
        courtId: m['courtId'] ?? '',
        courtName: m['courtName'] ?? '',
        customerName: m['customerName'] ?? '',
        customerId: m['customerId'] ?? '',
        ownerId: m['ownerId'] ?? '',
        bookedByRole: m['bookedByRole'] ?? 'customer',
        date: m['date'] is String
            ? DateTime.parse(m['date'])
            : (m['date'] as dynamic).toDate(),
        startHour: (m['startHour'] ?? 0) as int,
        totalHours: (m['totalHours'] ?? 1) as int,
        pricePerHour: (m['pricePerHour'] ?? 0).toDouble(),
        status: BookingStatus.values.firstWhere(
          (s) => s.key == m['status'],
          orElse: () => BookingStatus.pendingDeposit,
        ),
        depositScreenshot: m['depositPayment']?['screenshot'],
        createdAt: m['createdAt'] is String
            ? DateTime.parse(m['createdAt'])
            : (m['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
        checkedIn: m['checkedIn'] ?? false,
        checkedInAt: m['checkedInAt'] != null
            ? (m['checkedInAt'] as dynamic).toDate()
            : null,
        hasReview: m['hasReview'] ?? false,
        noShow: m['noShow'] ?? false,
        totalAmountStored: m['totalAmount'] != null
            ? (m['totalAmount'] as num).toDouble()
            : null,
        rescheduleRequest: m['rescheduleRequest'] != null
            ? RescheduleRequest.fromMap(
                m['rescheduleRequest'] as Map<String, dynamic>)
            : null,
        recurringGroupId: m['recurringGroupId'] as String?,
        recurringWeek: m['recurringWeek'] as int?,
        recurringTotal: m['recurringTotal'] as int?,
        isGroupBooking: m['isGroupBooking'] ?? false,
        groupSize: (m['groupSize'] ?? 1) as int,
        joinCode: m['joinCode'] as String?,
      );

  bool get isRecurring => recurringGroupId != null;

  double get splitAmount => groupSize > 1 ? totalAmount / groupSize : totalAmount;

  BookingModel copyWith({
    BookingStatus? status,
    String? depositScreenshot,
    CancellationInfo? cancellation,
    String? customerId,
    String? ownerId,
    bool? hasReview,
    RescheduleRequest? rescheduleRequest,
  }) =>
      BookingModel(
        id: id,
        arenaId: arenaId,
        arenaName: arenaName,
        courtId: courtId,
        courtName: courtName,
        customerId: customerId ?? this.customerId,
        ownerId: ownerId ?? this.ownerId,
        customerName: customerName,
        bookedByRole: bookedByRole,
        date: date,
        startHour: startHour,
        totalHours: totalHours,
        pricePerHour: pricePerHour,
        status: status ?? this.status,
        depositScreenshot: depositScreenshot ?? this.depositScreenshot,
        cancellation: cancellation ?? this.cancellation,
        createdAt: createdAt,
        checkedIn: checkedIn,
        checkedInAt: checkedInAt,
        hasReview: hasReview ?? this.hasReview,
        noShow: noShow,
        rescheduleRequest: rescheduleRequest ?? this.rescheduleRequest,
        recurringGroupId: recurringGroupId,
        recurringWeek: recurringWeek,
        recurringTotal: recurringTotal,
        isGroupBooking: isGroupBooking,
        groupSize: groupSize,
        joinCode: joinCode,
      );
}
