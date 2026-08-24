import 'package:cloud_firestore/cloud_firestore.dart';

/// Immutable audit log entry persisted to Firestore `audit_logs/{logId}`.
/// Never update or delete a log — append only.
class AuditLogModel {
  final String id;

  // Actor
  final String actorId;
  final String actorName;
  final String actorRole;

  // Action
  final String action;
  final String entityType;
  final String entityId;

  // Payload — stored as JSON-safe maps; null = not applicable
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;

  // Metadata
  final DateTime timestamp;
  final String platform;
  final String appVersion;
  final bool success;
  final String? errorMessage;
  final String? reason;

  const AuditLogModel({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.oldData,
    this.newData,
    required this.timestamp,
    this.platform = 'flutter',
    this.appVersion = '1.0.0',
    this.success = true,
    this.errorMessage,
    this.reason,
  });

  factory AuditLogModel.fromMap(Map<String, dynamic> m, String id) =>
      AuditLogModel(
        id: id,
        actorId: m['actorId'] ?? '',
        actorName: m['actorName'] ?? '',
        actorRole: m['actorRole'] ?? '',
        action: m['action'] ?? '',
        entityType: m['entityType'] ?? '',
        entityId: m['entityId'] ?? '',
        oldData: m['oldData'] != null ? Map<String, dynamic>.from(m['oldData']) : null,
        newData: m['newData'] != null ? Map<String, dynamic>.from(m['newData']) : null,
        timestamp: (m['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        platform: m['platform'] ?? 'flutter',
        appVersion: m['appVersion'] ?? '1.0.0',
        success: m['success'] ?? true,
        errorMessage: m['errorMessage'],
        reason: m['reason'],
      );

  Map<String, dynamic> toMap() => {
        'actorId': actorId,
        'actorName': actorName,
        'actorRole': actorRole,
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        if (oldData != null) 'oldData': oldData,
        if (newData != null) 'newData': newData,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': platform,
        'appVersion': appVersion,
        'success': success,
        if (errorMessage != null) 'errorMessage': errorMessage,
        if (reason != null) 'reason': reason,
      };

  @override
  bool operator ==(Object other) =>
      other is AuditLogModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Strongly-typed action constants — prevents typos in log entries.
abstract class AuditAction {
  // Arena
  static const String arenaApproved = 'arena.approved';
  static const String arenaRejected = 'arena.rejected';
  static const String arenaSuspended = 'arena.suspended';
  static const String arenaRestored = 'arena.restored';
  static const String arenaDeleted = 'arena.deleted';
  static const String arenaFeatured = 'arena.featured';
  static const String arenaUnfeatured = 'arena.unfeatured';
  static const String arenaCarouselAdded = 'arena.carousel.added';
  static const String arenaCarouselRemoved = 'arena.carousel.removed';
  static const String arenaCarouselOrderSet = 'arena.carousel.order_set';
  static const String arenaDocsVerified = 'arena.docs.verified';
  static const String arenaDocsUnverified = 'arena.docs.unverified';
  static const String arenaToggled = 'arena.toggled';

  // Booking
  static const String bookingCancelled = 'booking.cancelled';
  static const String bookingRefunded = 'booking.refunded';
  static const String bookingNoShow = 'booking.no_show';

  // User
  static const String userBanned = 'user.banned';
  static const String userUnbanned = 'user.unbanned';
  static const String userRoleChanged = 'user.role_changed';
  static const String userDeleted = 'user.deleted';
  static const String userSuspended = 'user.suspended';
  static const String userRestored = 'user.restored';
  static const String userDeactivated = 'user.deactivated';
  static const String userArchived = 'user.archived';
  static const String accountStatusChanged = 'account_status.changed';

  // Admin management
  static const String adminInvited = 'admin.invited';
  static const String adminActivated = 'admin.activated';
  static const String adminPermissionsChanged = 'admin.permissions_changed';

  // Owner self-registration
  static const String ownerSelfRegistered = 'owner.self_registered';
  static const String ownerApproved = 'owner.approved';
  static const String ownerRejected = 'owner.rejected';

  // Boost
  static const String boostApproved = 'boost.approved';
  static const String boostRejected = 'boost.rejected';

  // Settings
  static const String settingsUpdated = 'settings.updated';

  // Auth
  static const String adminLogin = 'auth.admin_login';
  static const String adminLogout = 'auth.admin_logout';

  // Finance / Payouts
  static const String payoutMarkedPaid = 'finance.payout_paid';
  static const String bookingRefundedAdmin = 'finance.booking_refunded';
  static const String bookingCancelledAdmin = 'booking.cancelled_admin';
  static const String bookingApprovedAdmin = 'booking.approved_admin';
  static const String bookingForceCompleted = 'booking.force_completed';

  // Customer management
  static const String customerSuspended = 'customer.suspended';
  static const String customerUnsuspended = 'customer.unsuspended';
  static const String customerVerified = 'customer.verified';
  static const String customerPasswordReset = 'customer.password_reset';
}
