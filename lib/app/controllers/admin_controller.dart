import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../data/models/arena_model.dart';
import '../data/models/boost_request_model.dart';
import '../data/models/user_model.dart';
import '../services/arena_service.dart';
import '../services/boost_service.dart';

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

/// Admin notification — in-memory; FCM replaces this in a later phase.
class AdminNotification {
  final String title;
  final String body;
  final String type;
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

/// Platform-wide admin state — streamed from Firestore.
class AdminController extends GetxController {
  static AdminController get to => Get.find();

  final _arenaService = ArenaService();
  final _boostService = BoostService();
  final _db = FirebaseFirestore.instance;

  final RxList<ArenaModel> arenas = <ArenaModel>[].obs;
  final RxList<BoostRequestModel> boosts = <BoostRequestModel>[].obs;
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxList<AuditLog> logs = <AuditLog>[].obs;
  final RxList<AdminNotification> notifications = <AdminNotification>[].obs;

  final RxSet<String> verifiedArenaDocs = <String>{}.obs;

  final RxInt depositPercent = 30.obs;
  final RxInt cancellationDeductPercent = 20.obs;
  final RxInt minCancelHoursBefore = 1.obs;
  final RxString jazzCashNumber = '0300-0000000'.obs;

  StreamSubscription? _arenasSub;
  StreamSubscription? _boostsSub;
  StreamSubscription? _usersSub;

  @override
  void onInit() {
    super.onInit();
    _arenasSub = _arenaService.allArenas().listen((list) => arenas.assignAll(list));
    _boostsSub = _boostService.allRequests().listen((list) => boosts.assignAll(list));
    _usersSub = _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((s) => users.assignAll(
              s.docs.map((d) => UserModel.fromMap({...d.data(), 'uid': d.id})).toList(),
            ));
    _loadSettings();
    refreshStats();
  }

  @override
  void onClose() {
    _arenasSub?.cancel();
    _boostsSub?.cancel();
    _usersSub?.cancel();
    super.onClose();
  }

  Future<void> _loadSettings() async {
    final doc = await _db.collection('settings').doc('booking').get();
    if (!doc.exists) return;
    final d = doc.data()!;
    depositPercent.value = (d['depositPercent'] ?? 30) as int;
    cancellationDeductPercent.value = (d['cancellationDeductPercent'] ?? 20) as int;
    minCancelHoursBefore.value = (d['minCancelHoursBefore'] ?? 1) as int;
    jazzCashNumber.value = d['jazzCashNumber'] ?? '0300-0000000';
    final verified = List<String>.from(d['verifiedArenaDocs'] ?? []);
    verifiedArenaDocs.assignAll(verified.toSet());
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
    _db.collection('auditLogs').add({
      'actorName': 'Admin',
      'actorRole': 'admin',
      'action': action,
      'target': target,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Derived lists ────────────────────────────────────────────────────

  List<ArenaModel> get pendingArenas =>
      arenas.where((a) => a.status == ArenaStatus.pending).toList();

  List<BoostRequestModel> get pendingBoosts =>
      boosts.where((b) => b.status == 'pending').toList();

  List<BoostRequestModel> get activeBoosts =>
      boosts.where((b) => b.status == 'approved').toList();

  // ── Arena management ─────────────────────────────────────────────────

  Future<void> setArenaStatus(String id, ArenaStatus status) async {
    await _arenaService.setStatus(id, status);
    _log('Arena ${status.name}', arenas.firstWhereOrNull((a) => a.id == id)?.name ?? id);
  }

  Future<void> toggleArenaActive(String id) async {
    final arena = arenas.firstWhereOrNull((a) => a.id == id);
    if (arena == null) return;
    final next = !arena.isActive;
    await _arenaService.toggleActive(id, next);
    _log(next ? 'Arena turned ON' : 'Arena forced OFF', arena.name);
  }

  void toggleDocsVerified(String id) {
    final name = arenas.firstWhereOrNull((a) => a.id == id)?.name ?? id;
    final isVerified = verifiedArenaDocs.contains(id);
    if (isVerified) {
      verifiedArenaDocs.remove(id);
    } else {
      verifiedArenaDocs.add(id);
    }
    _db.collection('settings').doc('booking').update({
      'verifiedArenaDocs': verifiedArenaDocs.toList(),
    });
    _log(isVerified ? 'Arena documents unverified' : 'Arena documents verified', name);
  }

  // ── Boost management ─────────────────────────────────────────────────

  Future<void> setBoostStatus(String id, String status) async {
    await _boostService.updateStatus(id, status);
    _log('Boost $status', boosts.firstWhereOrNull((b) => b.id == id)?.arenaName ?? id);
  }

  // ── User management ──────────────────────────────────────────────────

  Future<void> toggleBan(String uid) async {
    final user = users.firstWhereOrNull((u) => u.uid == uid);
    if (user == null) return;
    final next = !user.isActive;
    await _db.collection('users').doc(uid).update({'isActive': next});
    _log(next ? 'User unbanned' : 'User banned', user.name);
  }

  Future<void> changeRole(String uid, UserRole role) async {
    final user = users.firstWhereOrNull((u) => u.uid == uid);
    if (user == null) return;
    await _db.collection('users').doc(uid).update({'role': role.value});
    _log('Role changed to ${role.name}', user.name);
  }

  // ── Platform settings ────────────────────────────────────────────────

  Future<void> saveSettings({
    required int deposit,
    required int deduct,
    required int minHours,
    required String jazzCash,
  }) async {
    await _db.collection('settings').doc('booking').set({
      'depositPercent': deposit,
      'cancellationDeductPercent': deduct,
      'minCancelHoursBefore': minHours,
      'jazzCashNumber': jazzCash,
    }, SetOptions(merge: true));
    depositPercent.value = deposit;
    cancellationDeductPercent.value = deduct;
    minCancelHoursBefore.value = minHours;
    jazzCashNumber.value = jazzCash;
    _log('Platform settings updated', 'settings/booking');
  }

  // ── Notifications (in-memory; FCM in next phase) ─────────────────────

  int get unreadNotifications =>
      notifications.where((n) => !n.isRead).length;

  void markAllNotificationsRead() {
    for (var i = 0; i < notifications.length; i++) {
      notifications[i] = notifications[i].copyWith(isRead: true);
    }
  }

  // ── Dashboard stats ──────────────────────────────────────────────────

  int get totalArenas => arenas.length;
  int get totalUsers => users.length;
  int get totalOwners => users.where((u) => u.role == UserRole.owner).length;
  int get totalStaff => users.where((u) => u.role == UserRole.staff).length;

  // ── Booking stats — aggregated via Cloud Function in production;
  // read from Firestore stats doc for now.
  final RxInt totalBookings = 0.obs;
  final RxInt todaysBookings = 0.obs;
  final RxDouble monthlyRevenue = 0.0.obs;
  final RxDouble platformRevenue = 0.0.obs;

  Future<void> refreshStats() async {
    final doc = await _db.collection('settings').doc('stats').get();
    if (!doc.exists) return;
    final d = doc.data()!;
    totalBookings.value = (d['totalBookings'] ?? 0) as int;
    todaysBookings.value = (d['todaysBookings'] ?? 0) as int;
    monthlyRevenue.value = (d['monthlyRevenue'] ?? 0.0).toDouble();
    platformRevenue.value = (d['platformRevenue'] ?? 0.0).toDouble();
  }

  UserModel? ownerOf(String ownerId) =>
      users.firstWhereOrNull((u) => u.uid == ownerId);
}
