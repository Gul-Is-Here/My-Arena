import 'package:cloud_firestore/cloud_firestore.dart';

/// Explicit payment state, stored separately from booking lifecycle state.
/// This allows "confirmed but deposit still owed" and "confirmed, fully paid"
/// to be distinguished without overloading BookingStatus.
enum PaymentStatus {
  unpaid,
  depositSubmitted, // bank transfer screenshot uploaded, pending owner review
  depositAccepted,  // owner approved; remaining amount still owed
  fullyPaid,        // remaining collected at POS checkout
  refunded,
  failed,
}

extension PaymentStatusX on PaymentStatus {
  String get key {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'unpaid';
      case PaymentStatus.depositSubmitted:
        return 'deposit_submitted';
      case PaymentStatus.depositAccepted:
        return 'deposit_accepted';
      case PaymentStatus.fullyPaid:
        return 'fully_paid';
      case PaymentStatus.refunded:
        return 'refunded';
      case PaymentStatus.failed:
        return 'failed';
    }
  }

  String get label {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'Unpaid';
      case PaymentStatus.depositSubmitted:
        return 'Deposit Submitted';
      case PaymentStatus.depositAccepted:
        return 'Deposit Accepted';
      case PaymentStatus.fullyPaid:
        return 'Fully Paid';
      case PaymentStatus.refunded:
        return 'Refunded';
      case PaymentStatus.failed:
        return 'Payment Failed';
    }
  }
}

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

  // ── POS / walk-in payment method ──────────────────────────────────────
  /// Non-null only for owner manual bookings. Values: 'cash', 'jazzcash', 'easypaisa', 'card'.
  final String? posPaymentMethod;

  // ── POS payment amounts ────────────────────────────────────────────────
  /// Amount actually collected at the time of booking (POS/walk-in only).
  /// Null = online booking (uses 30% deposit model instead).
  final double? amountPaid;

  /// True for bookings created through the POS walk-in flow.
  final bool isPosBooking;

  /// Discount applied at POS (absolute amount, e.g. 200.0 = PKR 200 off).
  final double posDiscount;

  /// List of add-on product IDs included in this booking.
  final List<String> posAddOnIds;

  /// Total cost of POS add-ons (stored to avoid re-fetching product prices).
  final double posAddOnsTotal;

  // ── Minute-level extension (owner-approved sub-hour extension) ────────
  /// Total extra minutes granted beyond the original `totalHours` end time.
  /// Updated atomically when the owner approves an ExtensionRequest.
  final int extensionMinutes;

  // ── Promotions / coupons ─────────────────────────────────────────────
  /// ID of the PromotionModel applied to this booking (null if none).
  final String? appliedPromoId;

  /// Normalized promo code the customer entered (e.g. "ARENA10").
  final String? appliedPromoCode;

  /// Discount amount in PKR granted by the promotion.
  final double promoDiscount;

  /// Scope of the applied promo: 'platform' or 'arena'. Used to show "Platform Offer" vs "Arena Special".
  final String? appliedPromoScope;

  // ── Payment status ────────────────────────────────────────────────────
  /// Explicit payment state stored in Firestore. When absent in old documents
  /// it is derived from [status] and [amountPaid] via [derivedPaymentStatus].
  final PaymentStatus? paymentStatus;

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
    this.extensionMinutes = 0,
    this.isGroupBooking = false,
    this.groupSize = 1,
    this.joinCode,
    this.posPaymentMethod,
    this.amountPaid,
    this.isPosBooking = false,
    this.posDiscount = 0,
    this.posAddOnIds = const [],
    this.posAddOnsTotal = 0,
    this.appliedPromoId,
    this.appliedPromoCode,
    this.promoDiscount = 0,
    this.appliedPromoScope,
    this.paymentStatus,
  });

  /// Resolved payment status: explicit stored value wins; falls back to
  /// deriving from booking lifecycle state for backward-compat with old docs.
  PaymentStatus get effectivePaymentStatus {
    if (paymentStatus != null) return paymentStatus!;
    return derivedPaymentStatus;
  }

  PaymentStatus get derivedPaymentStatus {
    if (amountPaid != null && amountPaid! >= totalAmount - 1) {
      return PaymentStatus.fullyPaid;
    }
    if (status == BookingStatus.refundPending ||
        status == BookingStatus.refundSent ||
        status == BookingStatus.refundConfirmed) {
      return PaymentStatus.refunded;
    }
    if (status == BookingStatus.confirmed ||
        status == BookingStatus.ongoing ||
        status == BookingStatus.completed) {
      return PaymentStatus.depositAccepted;
    }
    if (status == BookingStatus.depositSubmitted) {
      return PaymentStatus.depositSubmitted;
    }
    return PaymentStatus.unpaid;
  }

  double get totalAmount =>
      (totalAmountStored ?? pricePerHour * totalHours) +
      posAddOnsTotal -
      posDiscount -
      promoDiscount +
      (pricePerHour * extensionMinutes / 60);
  double get depositAmount =>
      totalAmount * BookingSettings.depositPercent / 100;

  // When amountPaid is set (checkout recorded it), use the actual paid value for
  // both POS and online bookings. Fall back to the deposit formula for online
  // bookings that haven't had a checkout yet (amountPaid is still null).
  double get remainingAmount {
    if (amountPaid != null) {
      return (totalAmount - amountPaid!).clamp(0.0, double.infinity);
    }
    if (!isPosBooking) return totalAmount - depositAmount;
    return totalAmount;
  }

  DateTime get startDateTime =>
      DateTime(date.year, date.month, date.day, startHour);
  DateTime get endDateTime =>
      startDateTime.add(Duration(hours: totalHours, minutes: extensionMinutes));

  int get endHour => (startHour + totalHours) % 24;

  String get timeRange {
    final base = '${_fmtHour(startHour)} – ${_fmtHour(startHour + totalHours)}';
    if (extensionMinutes <= 0) return base;
    final extEnd = startDateTime.add(Duration(hours: totalHours, minutes: extensionMinutes));
    final extHour = extEnd.hour.toString().padLeft(2, '0');
    final extMin = extEnd.minute.toString().padLeft(2, '0');
    return '${_fmtHour(startHour)} – $extHour:$extMin';
  }

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
        if (extensionMinutes > 0) 'extensionMinutes': extensionMinutes,
        if (isGroupBooking) 'isGroupBooking': true,
        if (isGroupBooking) 'groupSize': groupSize,
        if (joinCode != null) 'joinCode': joinCode,
        if (posPaymentMethod != null) 'posPaymentMethod': posPaymentMethod,
        if (isPosBooking) 'isPosBooking': true,
        if (amountPaid != null) 'amountPaid': amountPaid,
        if (posDiscount > 0) 'posDiscount': posDiscount,
        if (posAddOnIds.isNotEmpty) 'posAddOnIds': posAddOnIds,
        if (posAddOnsTotal > 0) 'posAddOnsTotal': posAddOnsTotal,
        if (appliedPromoId != null) 'appliedPromoId': appliedPromoId,
        if (appliedPromoCode != null) 'appliedPromoCode': appliedPromoCode,
        if (promoDiscount > 0) 'promoDiscount': promoDiscount,
        if (appliedPromoScope != null) 'appliedPromoScope': appliedPromoScope,
        if (paymentStatus != null) 'paymentStatus': paymentStatus!.key,
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
        posPaymentMethod: m['posPaymentMethod'] as String?,
        isPosBooking: m['isPosBooking'] ?? false,
        amountPaid: m['amountPaid'] != null ? (m['amountPaid'] as num).toDouble() : null,
        posDiscount: (m['posDiscount'] as num?)?.toDouble() ?? 0,
        posAddOnIds: List<String>.from(m['posAddOnIds'] as List? ?? []),
        posAddOnsTotal: (m['posAddOnsTotal'] as num?)?.toDouble() ?? 0,
        extensionMinutes: (m['extensionMinutes'] as int?) ?? 0,
        appliedPromoId: m['appliedPromoId'] as String?,
        appliedPromoCode: m['appliedPromoCode'] as String?,
        promoDiscount: (m['promoDiscount'] as num?)?.toDouble() ?? 0,
        appliedPromoScope: m['appliedPromoScope'] as String?,
        paymentStatus: m['paymentStatus'] != null
            ? PaymentStatus.values.firstWhere(
                (s) => s.key == m['paymentStatus'],
                orElse: () => PaymentStatus.unpaid,
              )
            : null,
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
    String? posPaymentMethod,
    double? amountPaid,
    bool? isPosBooking,
    double? posDiscount,
    List<String>? posAddOnIds,
    double? posAddOnsTotal,
    int? extensionMinutes,
    String? appliedPromoId,
    String? appliedPromoCode,
    double? promoDiscount,
    PaymentStatus? paymentStatus,
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
        posPaymentMethod: posPaymentMethod ?? this.posPaymentMethod,
        amountPaid: amountPaid ?? this.amountPaid,
        isPosBooking: isPosBooking ?? this.isPosBooking,
        posDiscount: posDiscount ?? this.posDiscount,
        posAddOnIds: posAddOnIds ?? this.posAddOnIds,
        posAddOnsTotal: posAddOnsTotal ?? this.posAddOnsTotal,
        extensionMinutes: extensionMinutes ?? this.extensionMinutes,
        totalAmountStored: totalAmountStored,
        appliedPromoId: appliedPromoId ?? this.appliedPromoId,
        appliedPromoCode: appliedPromoCode ?? this.appliedPromoCode,
        promoDiscount: promoDiscount ?? this.promoDiscount,
        paymentStatus: paymentStatus ?? this.paymentStatus,
      );
}
