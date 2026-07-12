import 'package:get/get.dart';

import '../data/dummy_data.dart';
import '../data/models/arena_model.dart';
import '../data/models/boost_request_model.dart';
import '../data/models/user_model.dart';

/// Audit log entry — mirrors Firestore auditLogs/{logId}.
class AuditLog {
  final String actorName;
  final String actorRole;
  final String action;
  final String target;
  final DateTime timestamp;

  const AuditLog({
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.target,
    required this.timestamp,
  });
}

/// Admin notification — mirrors Firestore notifications/{uid}/items (FCM later).
class AdminNotification {
  final String title;
  final String body;
  final String type; // booking | ticket | boost | tournament | arena | payment
  final DateTime timestamp;
  final bool isRead;

  const AdminNotification({
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  AdminNotification copyWith({bool? isRead}) => AdminNotification(
        title: title,
        body: body,
        type: type,
        timestamp: timestamp,
        isRead: isRead ?? this.isRead,
      );
}

/// Platform-wide admin state — arenas, boosts, users, settings, logs.
/// Dummy data now; Firestore repositories in the backend phase.
class AdminController extends GetxController {
  static AdminController get to => Get.find();

  final RxList<ArenaModel> arenas = <ArenaModel>[].obs;
  final RxList<BoostRequestModel> boosts = <BoostRequestModel>[].obs;
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxList<AuditLog> logs = <AuditLog>[].obs;
  final RxList<AdminNotification> notifications = <AdminNotification>[].obs;

  /// Arena ids whose ownership/registration documents are verified.
  final RxSet<String> verifiedArenaDocs = <String>{}.obs;

  // Editable platform settings (mirrors Firestore settings/booking).
  final RxInt depositPercent = 30.obs;
  final RxInt cancellationDeductPercent = 20.obs;
  final RxInt minCancelHoursBefore = 1.obs;
  final RxString jazzCashNumber = DummyData.jazzCashNumber.obs;

  List<ArenaModel> get pendingArenas =>
      arenas.where((a) => a.status == ArenaStatus.pending).toList();

  List<BoostRequestModel> get pendingBoosts =>
      boosts.where((b) => b.status == 'pending').toList();

  List<BoostRequestModel> get activeBoosts =>
      boosts.where((b) => b.status == 'approved').toList();

  @override
  void onInit() {
    super.onInit();
    arenas.assignAll(DummyData.arenas);
    boosts.assignAll(DummyData.boostRequests);
    _seedUsers();
    _seedLogs();
    _seedNotifications();
    verifiedArenaDocs.addAll(['arena-1', 'arena-3']);
  }

  void _log(String action, String target) {
    logs.insert(
      0,
      AuditLog(
        actorName: 'Admin',
        actorRole: 'admin',
        action: action,
        target: target,
        timestamp: DateTime.now(),
      ),
    );
  }

  // ── Arena management ───────────────────────────────────────────────
  void setArenaStatus(String id, ArenaStatus status) {
    final i = arenas.indexWhere((a) => a.id == id);
    if (i == -1) return;
    arenas[i] = arenas[i].copyWith(status: status);
    _log('Arena ${status.name}', arenas[i].name);
  }

  void toggleArenaActive(String id) {
    final i = arenas.indexWhere((a) => a.id == id);
    if (i == -1) return;
    final next = !arenas[i].isActive;
    arenas[i] = arenas[i].copyWith(isActive: next);
    _log(next ? 'Arena turned ON' : 'Arena forced OFF', arenas[i].name);
  }

  void toggleDocsVerified(String id) {
    final name = arenas.firstWhereOrNull((a) => a.id == id)?.name ?? id;
    if (verifiedArenaDocs.contains(id)) {
      verifiedArenaDocs.remove(id);
      _log('Arena documents unverified', name);
    } else {
      verifiedArenaDocs.add(id);
      _log('Arena documents verified', name);
    }
  }

  // ── Boost management ───────────────────────────────────────────────
  void setBoostStatus(String id, String status) {
    final i = boosts.indexWhere((b) => b.id == id);
    if (i == -1) return;
    boosts[i] = boosts[i].copyWith(status: status);
    _log('Boost $status', boosts[i].arenaName);
  }

  // ── User management ────────────────────────────────────────────────
  void toggleBan(String uid) {
    final i = users.indexWhere((u) => u.uid == uid);
    if (i == -1) return;
    final next = !users[i].isActive;
    users[i] = users[i].copyWith(isActive: next);
    _log(next ? 'User unbanned' : 'User banned', users[i].name);
  }

  void changeRole(String uid, UserRole role) {
    final i = users.indexWhere((u) => u.uid == uid);
    if (i == -1) return;
    users[i] = users[i].copyWith(role: role);
    _log('Role changed to ${role.name}', users[i].name);
  }

  // ── Settings ───────────────────────────────────────────────────────
  void saveSettings({
    required int deposit,
    required int deduct,
    required int minHours,
    required String jazzCash,
  }) {
    depositPercent.value = deposit;
    cancellationDeductPercent.value = deduct;
    minCancelHoursBefore.value = minHours;
    jazzCashNumber.value = jazzCash;
    _log('Platform settings updated', 'settings/booking');
  }

  // ── Notifications ──────────────────────────────────────────────────
  int get unreadNotifications =>
      notifications.where((n) => !n.isRead).length;

  void markAllNotificationsRead() {
    for (var i = 0; i < notifications.length; i++) {
      notifications[i] = notifications[i].copyWith(isRead: true);
    }
  }

  // ── Dashboard stats ────────────────────────────────────────────────
  int get totalArenas => arenas.length;
  int get totalUsers => users.length;
  int get totalOwners =>
      users.where((u) => u.role == UserRole.owner).length;
  int get totalStaff =>
      users.where((u) => u.role == UserRole.staff).length;
  int get totalBookings => 412;
  int get todaysBookings => 23;
  double get monthlyRevenue => 385000;
  double get platformRevenue => 1250000;

  /// Dummy owner lookup — falls back to the seeded owner user until
  /// real ownerIds are wired to Firestore users.
  UserModel? ownerOf(String ownerId) =>
      users.firstWhereOrNull((u) => u.uid == ownerId) ??
      users.firstWhereOrNull((u) => u.role == UserRole.owner);

  void _seedNotifications() {
    final now = DateTime.now();
    notifications.assignAll([
      AdminNotification(
          title: 'New booking',
          body: 'Ali Raza booked Padel Court A at Champions Arena.',
          type: 'booking',
          timestamp: now.subtract(const Duration(minutes: 18))),
      AdminNotification(
          title: 'New support ticket',
          body: 'Ahmed Nawaz: "Charged twice for one booking".',
          type: 'ticket',
          timestamp: now.subtract(const Duration(minutes: 45))),
      AdminNotification(
          title: 'Boost request',
          body: 'Victory Sports Club requested a 2-week boost.',
          type: 'boost',
          timestamp: now.subtract(const Duration(hours: 2))),
      AdminNotification(
          title: 'Tournament request',
          body: 'Ramadan Night Padel Cup awaits approval.',
          type: 'tournament',
          timestamp: now.subtract(const Duration(hours: 4))),
      AdminNotification(
          title: 'Arena verification request',
          body: 'Victory Sports Club submitted registration documents.',
          type: 'arena',
          timestamp: now.subtract(const Duration(hours: 7)),
          isRead: true),
      AdminNotification(
          title: 'Payment issue',
          body: 'Deposit screenshot for booking #1101 flagged as unreadable.',
          type: 'payment',
          timestamp: now.subtract(const Duration(days: 1)),
          isRead: true),
    ]);
  }

  void _seedUsers() {
    users.assignAll(const [
      UserModel(
          uid: 'u1',
          name: 'Ali Raza',
          email: 'ali.raza@gmail.com',
          phone: '0300-1112233',
          role: UserRole.customer),
      UserModel(
          uid: 'u2',
          name: 'Hamza Sheikh',
          email: 'hamza.s@gmail.com',
          phone: '0301-4455667',
          role: UserRole.customer),
      UserModel(
          uid: 'u3',
          name: 'Usman Khalid',
          email: 'usman.k@gmail.com',
          phone: '0333-7788990',
          role: UserRole.owner),
      UserModel(
          uid: 'u4',
          name: 'Sara Malik',
          email: 'sara.malik@gmail.com',
          phone: '0345-2233445',
          role: UserRole.customer,
          isActive: false),
      UserModel(
          uid: 'u5',
          name: 'Bilal Ahmed',
          email: 'bilal.a@myarena.pk',
          phone: '0321-9988776',
          role: UserRole.staff),
      UserModel(
          uid: 'u6',
          name: 'Ayesha Tariq',
          email: 'ayesha.t@myarena.pk',
          phone: '0302-5566778',
          role: UserRole.staff),
    ]);
  }

  void _seedLogs() {
    final now = DateTime.now();
    logs.assignAll([
      AuditLog(
          actorName: 'Admin',
          actorRole: 'admin',
          action: 'Boost approved',
          target: 'Champions Arena',
          timestamp: now.subtract(const Duration(hours: 2))),
      AuditLog(
          actorName: 'Bilal Ahmed',
          actorRole: 'staff',
          action: 'Arena approved',
          target: 'Kick Off Futsal Park',
          timestamp: now.subtract(const Duration(hours: 8))),
      AuditLog(
          actorName: 'Admin',
          actorRole: 'admin',
          action: 'User banned',
          target: 'Sara Malik',
          timestamp: now.subtract(const Duration(days: 1))),
      AuditLog(
          actorName: 'Ayesha Tariq',
          actorRole: 'staff',
          action: 'Booking approved',
          target: 'Padel Court A · #1042',
          timestamp: now.subtract(const Duration(days: 1, hours: 4))),
      AuditLog(
          actorName: 'Admin',
          actorRole: 'admin',
          action: 'Platform settings updated',
          target: 'settings/booking',
          timestamp: now.subtract(const Duration(days: 3))),
    ]);
  }
}
