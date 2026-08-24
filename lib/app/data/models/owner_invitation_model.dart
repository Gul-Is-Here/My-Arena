import 'package:cloud_firestore/cloud_firestore.dart';

enum InvitationStatus { pending, accepted, expired, revoked }

extension InvitationStatusX on InvitationStatus {
  String get value => name;
  String get label => switch (this) {
        InvitationStatus.pending => 'Pending',
        InvitationStatus.accepted => 'Accepted',
        InvitationStatus.expired => 'Expired',
        InvitationStatus.revoked => 'Revoked',
      };

  static InvitationStatus fromString(String? s) =>
      InvitationStatus.values.firstWhere(
        (e) => e.name == s,
        orElse: () => InvitationStatus.pending,
      );
}

/// Mirrors Firestore `ownerInvitations/{id}`.
class OwnerInvitationModel {
  final String id;
  final String email;
  final String name;
  final String phone;

  /// UID of the admin who created the invitation.
  final String invitedBy;

  final InvitationStatus status;

  /// Firebase Auth UID of the target user. Null for new accounts until accepted.
  /// Populated immediately for existing-user upgrades (isUpgrade == true).
  final String? targetUid;

  /// Arena IDs pre-created by admin for this owner before they activate.
  final List<String> arenaIds;

  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;
  final String? revokedBy;

  /// How many times the invite was resent.
  final int resendCount;
  final DateTime? lastResentAt;

  /// True when an existing customer/staff was upgraded rather than a new account created.
  final bool isUpgrade;

  const OwnerInvitationModel({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.invitedBy,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.targetUid,
    this.arenaIds = const [],
    this.acceptedAt,
    this.revokedAt,
    this.revokedBy,
    this.resendCount = 0,
    this.lastResentAt,
    this.isUpgrade = false,
  });

  bool get isExpired =>
      status == InvitationStatus.expired ||
      (status == InvitationStatus.pending &&
          DateTime.now().isAfter(expiresAt));

  bool get canResend =>
      status == InvitationStatus.pending &&
      !isExpired &&
      resendCount < 5 &&
      (lastResentAt == null ||
          DateTime.now().difference(lastResentAt!).inMinutes >= 60);

  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now());

  factory OwnerInvitationModel.fromMap(Map<String, dynamic> m, String docId) {
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

    return OwnerInvitationModel(
      id: docId,
      email: m['email'] as String? ?? '',
      name: m['name'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      invitedBy: m['invitedBy'] as String? ?? '',
      status: InvitationStatusX.fromString(m['status'] as String?),
      targetUid: m['targetUid'] as String?,
      arenaIds: List<String>.from(m['arenaIds'] ?? []),
      expiresAt: toDateTime(m['expiresAt']),
      createdAt: toDateTime(m['createdAt']),
      acceptedAt: toDateTimeNullable(m['acceptedAt']),
      revokedAt: toDateTimeNullable(m['revokedAt']),
      revokedBy: m['revokedBy'] as String?,
      resendCount: (m['resendCount'] as int?) ?? 0,
      lastResentAt: toDateTimeNullable(m['lastResentAt']),
      isUpgrade: m['isUpgrade'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'name': name,
        'phone': phone,
        'invitedBy': invitedBy,
        'status': status.value,
        if (targetUid != null) 'targetUid': targetUid,
        'arenaIds': arenaIds,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': Timestamp.fromDate(createdAt),
        if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
        if (revokedAt != null) 'revokedAt': Timestamp.fromDate(revokedAt!),
        if (revokedBy != null) 'revokedBy': revokedBy,
        'resendCount': resendCount,
        if (lastResentAt != null) 'lastResentAt': Timestamp.fromDate(lastResentAt!),
        'isUpgrade': isUpgrade,
      };

  OwnerInvitationModel copyWith({
    InvitationStatus? status,
    String? targetUid,
    List<String>? arenaIds,
    DateTime? acceptedAt,
    DateTime? revokedAt,
    String? revokedBy,
    int? resendCount,
    DateTime? lastResentAt,
  }) =>
      OwnerInvitationModel(
        id: id,
        email: email,
        name: name,
        phone: phone,
        invitedBy: invitedBy,
        status: status ?? this.status,
        targetUid: targetUid ?? this.targetUid,
        arenaIds: arenaIds ?? this.arenaIds,
        expiresAt: expiresAt,
        createdAt: createdAt,
        acceptedAt: acceptedAt ?? this.acceptedAt,
        revokedAt: revokedAt ?? this.revokedAt,
        revokedBy: revokedBy ?? this.revokedBy,
        resendCount: resendCount ?? this.resendCount,
        lastResentAt: lastResentAt ?? this.lastResentAt,
        isUpgrade: isUpgrade,
      );
}
