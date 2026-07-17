import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors Firestore bookings/{bookingId} from scope.md.
enum BookingStatus {
  pendingDeposit,
  depositSubmitted,
  confirmed,
  rejected,
  completed,
  cancelled,
  refundPending,
  refundSent,
  refundConfirmed,
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
    }
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
  });

  double get totalAmount => pricePerHour * totalHours;
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

  bool get isActive => status == BookingStatus.confirmed && checkedIn;

  String get displayLabel => isActive ? 'Active' : status.label;

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
      );

  BookingModel copyWith({
    BookingStatus? status,
    String? depositScreenshot,
    CancellationInfo? cancellation,
    String? customerId,
    String? ownerId,
    bool? hasReview,
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
      );
}
