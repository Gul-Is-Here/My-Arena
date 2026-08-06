/// Account lifecycle state. Stored as string in Firestore `accountStatus` field.
/// Replaces the old boolean `isActive` field.
enum AccountStatus {
  /// Self-registered owner awaiting admin approval, or invited user not yet accepted.
  pending,

  /// Fully active — can sign in and use the app.
  active,

  /// Temporarily blocked by admin. Real-time stream forces sign-out mid-session.
  suspended,

  /// Admin-soft-deleted. Not visible in normal lists but data is retained.
  inactive,

  /// Permanently archived. Never re-activatable via UI — requires manual DB edit.
  archived;

  static AccountStatus fromString(String? s) =>
      AccountStatus.values.firstWhere(
        (v) => v.name == s,
        orElse: () => AccountStatus.active,
      );

  String get label => switch (this) {
        AccountStatus.pending => 'Pending',
        AccountStatus.active => 'Active',
        AccountStatus.suspended => 'Suspended',
        AccountStatus.inactive => 'Inactive',
        AccountStatus.archived => 'Archived',
      };
}

/// Mirrors Firestore users/{uid}.role field.
/// Keep snake_case values that match Firestore — use [UserRoleX.fromString].
enum UserRole {
  customer,
  owner,
  staff,
  admin,
  superAdmin,
  operationsManager,
  supportAgent,
  finance,
  contentManager,
  moderator,
}

extension UserRoleX on UserRole {
  String get value => name;

  String get label => switch (this) {
        UserRole.customer => 'Customer',
        UserRole.owner => 'Arena Owner',
        UserRole.staff => 'Staff',
        UserRole.admin => 'Admin',
        UserRole.superAdmin => 'Super Admin',
        UserRole.operationsManager => 'Operations Manager',
        UserRole.supportAgent => 'Support Agent',
        UserRole.finance => 'Finance',
        UserRole.contentManager => 'Content Manager',
        UserRole.moderator => 'Moderator',
      };

  /// Returns true for any role that can access the admin panel.
  /// Note: staff is NOT admin-tier — staff have their own dedicated dashboard.
  bool get isAdminTier =>
      this == UserRole.admin ||
      this == UserRole.superAdmin ||
      this == UserRole.operationsManager ||
      this == UserRole.supportAgent ||
      this == UserRole.finance ||
      this == UserRole.contentManager ||
      this == UserRole.moderator;

  static UserRole fromString(String? role) => UserRole.values.firstWhere(
        (r) => r.name == role?.trim(),
        orElse: () => UserRole.customer,
      );
}

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final List<UserRole> roles;
  final String avatar;
  final AccountStatus accountStatus;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  // Staff-specific fields (non-null only when role == UserRole.staff with ownerId set)
  final String? ownerId;
  final List<String> assignedArenas;
  final Map<String, List<String>> arenaPermissions;

  // Admin management fields
  final String? invitedBy;
  final String? inviterRole;
  final int? ownerInviteLimit;
  final List<String> managedOwnerIds;
  final List<String> managedArenaIds;
  final Map<String, bool> customPermissions;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.role = UserRole.customer,
    this.roles = const [],
    this.avatar = '',
    this.accountStatus = AccountStatus.active,
    this.createdAt,
    this.lastLogin,
    this.ownerId,
    this.assignedArenas = const [],
    this.arenaPermissions = const {},
    this.invitedBy,
    this.inviterRole,
    this.ownerInviteLimit,
    this.managedOwnerIds = const [],
    this.managedArenaIds = const [],
    this.customPermissions = const {},
  });

  /// Backward-compatible getter — true only when fully active.
  bool get isActive => accountStatus == AccountStatus.active;

  bool get hasMultipleRoles => roles.length > 1;

  /// True for admin/superAdmin (unrestricted scope).
  bool get isFullAdmin =>
      role == UserRole.admin || role == UserRole.superAdmin;

  /// True when this admin-tier user has an explicit scope restriction.
  bool get isScoped =>
      role.isAdminTier &&
      !isFullAdmin &&
      (managedArenaIds.isNotEmpty || managedOwnerIds.isNotEmpty);

  /// True when this staff member is an owner-assigned arena staff (not admin support staff).
  bool get isArenaStaff => role == UserRole.staff && ownerId != null;

  /// Returns the permissions this staff member has for the given arena.
  List<String> permissionsFor(String arenaId) => arenaPermissions[arenaId] ?? [];

  bool canEditArena(String arenaId) => assignedArenas.contains(arenaId);
  bool canEditCourts(String arenaId) => assignedArenas.contains(arenaId);
  bool canManageBookings(String arenaId) => assignedArenas.contains(arenaId);
  bool canAccessChat(String arenaId) => assignedArenas.contains(arenaId);

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final primaryRole = UserRoleX.fromString(map['role']);
    final rolesList = (map['roles'] as List?)
            ?.map((r) => UserRoleX.fromString(r as String?))
            .toList() ??
        [primaryRole];

    final rawArenaPerms = map['arenaPermissions'] as Map<String, dynamic>?;
    final arenaPermissions = rawArenaPerms != null
        ? rawArenaPerms.map((k, v) => MapEntry(k, List<String>.from(v as List? ?? [])))
        : <String, List<String>>{};

    final rawCustomPerms = map['customPermissions'] as Map<String, dynamic>?;
    final customPermissions = rawCustomPerms != null
        ? rawCustomPerms.map((k, v) => MapEntry(k, v as bool? ?? false))
        : <String, bool>{};

    // Migration: if `accountStatus` not yet written, fall back to `isActive` bool.
    AccountStatus status;
    if (map['accountStatus'] != null) {
      status = AccountStatus.fromString(map['accountStatus'] as String?);
    } else {
      status = (map['isActive'] as bool? ?? true)
          ? AccountStatus.active
          : AccountStatus.suspended;
    }

    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: primaryRole,
      roles: rolesList,
      avatar: map['avatar'] ?? '',
      accountStatus: status,
      createdAt: (map['createdAt'] as dynamic)?.toDate(),
      lastLogin: (map['lastLogin'] as dynamic)?.toDate(),
      ownerId: map['ownerId'] as String?,
      assignedArenas: List<String>.from(map['assignedArenas'] as List? ?? []),
      arenaPermissions: arenaPermissions,
      invitedBy: map['invitedBy'] as String?,
      inviterRole: map['inviterRole'] as String?,
      ownerInviteLimit: map['ownerInviteLimit'] as int?,
      managedOwnerIds: List<String>.from(map['managedOwnerIds'] as List? ?? []),
      managedArenaIds: List<String>.from(map['managedArenaIds'] as List? ?? []),
      customPermissions: customPermissions,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.value,
        'roles': roles.map((r) => r.value).toList(),
        'avatar': avatar,
        'accountStatus': accountStatus.name,
      };

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    List<UserRole>? roles,
    String? avatar,
    AccountStatus? accountStatus,
    String? ownerId,
    List<String>? assignedArenas,
    Map<String, List<String>>? arenaPermissions,
    String? invitedBy,
    String? inviterRole,
    int? ownerInviteLimit,
    List<String>? managedOwnerIds,
    List<String>? managedArenaIds,
    Map<String, bool>? customPermissions,
  }) =>
      UserModel(
        uid: uid,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        roles: roles ?? this.roles,
        avatar: avatar ?? this.avatar,
        accountStatus: accountStatus ?? this.accountStatus,
        createdAt: createdAt,
        lastLogin: lastLogin,
        ownerId: ownerId ?? this.ownerId,
        assignedArenas: assignedArenas ?? this.assignedArenas,
        arenaPermissions: arenaPermissions ?? this.arenaPermissions,
        invitedBy: invitedBy ?? this.invitedBy,
        inviterRole: inviterRole ?? this.inviterRole,
        ownerInviteLimit: ownerInviteLimit ?? this.ownerInviteLimit,
        managedOwnerIds: managedOwnerIds ?? this.managedOwnerIds,
        managedArenaIds: managedArenaIds ?? this.managedArenaIds,
        customPermissions: customPermissions ?? this.customPermissions,
      );
}
