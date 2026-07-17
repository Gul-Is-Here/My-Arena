/// Mirrors Firestore users/{uid} document from scope.md.
enum UserRole { customer, owner, staff, admin }

extension UserRoleX on UserRole {
  String get value => name;

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
  final String avatar;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.role = UserRole.customer,
    this.avatar = '',
    this.isActive = true,
    this.createdAt,
    this.lastLogin,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        uid: map['uid'] ?? '',
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        phone: map['phone'] ?? '',
        role: UserRoleX.fromString(map['role']),
        avatar: map['avatar'] ?? '',
        isActive: map['isActive'] ?? true,
        createdAt: (map['createdAt'] as dynamic)?.toDate(),
        lastLogin: (map['lastLogin'] as dynamic)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.value,
        'avatar': avatar,
        'isActive': isActive,
      };

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? avatar,
    bool? isActive,
  }) =>
      UserModel(
        uid: uid,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        avatar: avatar ?? this.avatar,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        lastLogin: lastLogin,
      );
}
