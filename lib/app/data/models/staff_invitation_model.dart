class StaffInvitationModel {
  final String id;
  final String email;
  final String ownerId;
  final String ownerName;
  final List<String> assignedArenas;
  final List<String> arenaNames;
  final String status; // pending | accepted | expired | revoked
  final String? targetUid;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isExistingUser;

  const StaffInvitationModel({
    required this.id,
    required this.email,
    required this.ownerId,
    required this.ownerName,
    required this.assignedArenas,
    required this.arenaNames,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.targetUid,
    this.isExistingUser = false,
  });

  factory StaffInvitationModel.fromMap(String id, Map<String, dynamic> map) {
    return StaffInvitationModel(
      id: id,
      email: map['email'] ?? '',
      ownerId: map['ownerId'] ?? '',
      ownerName: map['ownerName'] ?? '',
      assignedArenas: List<String>.from(map['assignedArenas'] as List? ?? []),
      arenaNames: List<String>.from(map['arenaNames'] as List? ?? []),
      status: map['status'] ?? 'pending',
      targetUid: map['targetUid'] as String?,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as dynamic)?.toDate() ?? DateTime.now(),
      isExistingUser: map['isExistingUser'] ?? false,
    );
  }
}
