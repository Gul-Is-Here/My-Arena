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
  final String bookedByRole; // 'customer' | 'owner' | 'staff'
  final DateTime date;
  final int startHour; // 0–23, slot start
  final int totalHours;
  final double pricePerHour;
  final BookingStatus status;
  final String? depositScreenshot;
  final CancellationInfo? cancellation;
  final DateTime createdAt;

  const BookingModel({
    required this.id,
    required this.arenaId,
    required this.arenaName,
    required this.courtId,
    required this.courtName,
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

  BookingModel copyWith({
    BookingStatus? status,
    String? depositScreenshot,
    CancellationInfo? cancellation,
  }) =>
      BookingModel(
        id: id,
        arenaId: arenaId,
        arenaName: arenaName,
        courtId: courtId,
        courtName: courtName,
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
      );
}
