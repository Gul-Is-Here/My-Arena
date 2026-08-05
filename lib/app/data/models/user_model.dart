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
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  // Staff-specific fields (non-null only when role == UserRole.staff with ownerId set)
  final String? ownerId;
  final List<String> assignedArenas;
  final Map<String, List<String>> arenaPermissions;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.role = UserRole.customer,
    this.roles = const [],
    this.avatar = '',
    this.isActive = true,
    this.createdAt,
    this.lastLogin,
    this.ownerId,
    this.assignedArenas = const [],
    this.arenaPermissions = const {},
  });

  bool get hasMultipleRoles => roles.length > 1;

  /// True when this staff member is an owner-assigned arena staff (not admin support staff).
  bool get isArenaStaff => role == UserRole.staff && ownerId != null;

  /// Returns the permissions this staff member has for the given arena.
  List<String> permissionsFor(String arenaId) => arenaPermissions[arenaId] ?? [];

  bool canEditArena(String arenaId) => permissionsFor(arenaId).contains('edit_arena');
  bool canEditCourts(String arenaId) => permissionsFor(arenaId).contains('edit_courts');

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final primaryRole = UserRoleX.fromString(map['role']);
    final rolesList = (map['roles'] as List?)
            ?.map((r) => UserRoleX.fromString(r as String?))
            .toList() ??
        [primaryRole];

    final rawPerms = map['arenaPermissions'] as Map<String, dynamic>?;
    final arenaPermissions = rawPerms != null
        ? rawPerms.map((k, v) => MapEntry(k, List<String>.from(v as List? ?? [])))
        : <String, List<String>>{};

    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: primaryRole,
      roles: rolesList,
      avatar: map['avatar'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as dynamic)?.toDate(),
      lastLogin: (map['lastLogin'] as dynamic)?.toDate(),
      ownerId: map['ownerId'] as String?,
      assignedArenas: List<String>.from(map['assignedArenas'] as List? ?? []),
      arenaPermissions: arenaPermissions,
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
        'isActive': isActive,
      };

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    List<UserRole>? roles,
    String? avatar,
    bool? isActive,
    String? ownerId,
    List<String>? assignedArenas,
    Map<String, List<String>>? arenaPermissions,
  }) =>
      UserModel(
        uid: uid,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        roles: roles ?? this.roles,
        avatar: avatar ?? this.avatar,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        lastLogin: lastLogin,
        ownerId: ownerId ?? this.ownerId,
        assignedArenas: assignedArenas ?? this.assignedArenas,
        arenaPermissions: arenaPermissions ?? this.arenaPermissions,
      );
}
