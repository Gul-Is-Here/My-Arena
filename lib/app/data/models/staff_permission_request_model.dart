class StaffPermissionRequestModel {
  final String id;
  final String staffUid;
  final String staffName;
  final String ownerId;
  final String arenaId;
  final String arenaName;
  final List<String> permissions; // edit_arena, edit_courts
  final String reason;
  final String status; // pending | approved | denied
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const StaffPermissionRequestModel({
    required this.id,
    required this.staffUid,
    required this.staffName,
    required this.ownerId,
    required this.arenaId,
    required this.arenaName,
    required this.permissions,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });

  factory StaffPermissionRequestModel.fromMap(String id, Map<String, dynamic> map) {
    return StaffPermissionRequestModel(
      id: id,
      staffUid: map['staffUid'] ?? '',
      staffName: map['staffName'] ?? '',
      ownerId: map['ownerId'] ?? '',
      arenaId: map['arenaId'] ?? '',
      arenaName: map['arenaName'] ?? '',
      permissions: List<String>.from(map['permissions'] as List? ?? []),
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      resolvedAt: (map['resolvedAt'] as dynamic)?.toDate(),
    );
  }
}
