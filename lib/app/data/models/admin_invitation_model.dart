import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/owner_invitation_model.dart' show InvitationStatus, InvitationStatusX;
import '../models/user_model.dart' show UserRole, UserRoleX;

export '../models/owner_invitation_model.dart' show InvitationStatus, InvitationStatusX;

/// Mirrors Firestore `adminInvitations/{id}`.
class AdminInvitationModel {
  final String id;
  final String email;
  final String name;
  final String phone;

  /// UID of the admin who sent this invitation.
  final String invitedBy;

  /// Role of the inviter.
  final String inviterRole;

  /// The admin role being granted (admin, operationsManager, etc.).
  final UserRole targetRole;

  final InvitationStatus status;

  /// Firebase Auth UID of the invitee. Set immediately for upgrades.
  final String? targetUid;

  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;
  final String? revokedBy;

  final int resendCount;
  final DateTime? lastResentAt;

  /// True when an existing user was upgraded rather than a new account created.
  final bool isUpgrade;

  /// False until the invitee successfully logs in for the first time.
  final bool hasLoggedIn;

  const AdminInvitationModel({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.invitedBy,
    required this.inviterRole,
    required this.targetRole,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.targetUid,
    this.acceptedAt,
    this.revokedAt,
    this.revokedBy,
    this.resendCount = 0,
    this.lastResentAt,
    this.isUpgrade = false,
    this.hasLoggedIn = false,
  });

  bool get isExpired =>
      status == InvitationStatus.expired ||
      (status == InvitationStatus.pending && DateTime.now().isAfter(expiresAt));

  bool get canResend {
    if (resendCount >= 10) return false;
    final cooldownOk = lastResentAt == null ||
        DateTime.now().difference(lastResentAt!).inMinutes >= 60;
    if (!cooldownOk) return false;
    // Pending and not expired — resend fresh activation email
    if (status == InvitationStatus.pending && !isExpired) return true;
    // Accepted but admin hasn't logged in yet — resend login reminder
    if (status == InvitationStatus.accepted && !hasLoggedIn && !isUpgrade) return true;
    return false;
  }

  factory AdminInvitationModel.fromMap(Map<String, dynamic> m, String docId) {
    DateTime toDateTime(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.now();
    }

    DateTime? toDateTimeNullable(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return AdminInvitationModel(
      id: docId,
      email: m['email'] as String? ?? '',
      name: m['name'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      invitedBy: m['invitedBy'] as String? ?? '',
      inviterRole: m['inviterRole'] as String? ?? '',
      targetRole: UserRoleX.fromString(m['targetRole'] as String?),
      status: InvitationStatusX.fromString(m['status'] as String?),
      targetUid: m['targetUid'] as String?,
      expiresAt: toDateTime(m['expiresAt']),
      createdAt: toDateTime(m['createdAt']),
      acceptedAt: toDateTimeNullable(m['acceptedAt']),
      revokedAt: toDateTimeNullable(m['revokedAt']),
      revokedBy: m['revokedBy'] as String?,
      resendCount: (m['resendCount'] as int?) ?? 0,
      lastResentAt: toDateTimeNullable(m['lastResentAt']),
      isUpgrade: m['isUpgrade'] as bool? ?? false,
      hasLoggedIn: m['hasLoggedIn'] as bool? ?? false,
    );
  }
}
