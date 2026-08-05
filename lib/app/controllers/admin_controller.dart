import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../data/models/arena_model.dart';
import '../data/models/booking_model.dart';
import '../data/models/boost_request_model.dart';
import '../data/models/owner_invitation_model.dart';
import '../data/models/ticket_model.dart';
import '../data/models/user_model.dart';
import '../repositories/admin_repository.dart';
import '../services/arena_service.dart';
import '../services/boost_service.dart';
import '../services/otp_service.dart';

/// Admin notification — in-memory until FCM broadcast is wired in Phase 2.
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

/// Platform-wide admin state — all writes go through AdminRepository
/// so every action is automatically audit-logged to Firestore.
class AdminController extends GetxController {
  static AdminController get to => Get.find();

  final _repo = AdminRepository();
  final _arenaService = ArenaService();
  final _boostService = BoostService();
  final _db = FirebaseFirestore.instance;

  final RxList<ArenaModel> arenas = <ArenaModel>[].obs;
  final RxList<BoostRequestModel> boosts = <BoostRequestModel>[].obs;
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxList<AdminNotification> notifications = <AdminNotification>[].obs;

  final RxSet<String> verifiedArenaDocs = <String>{}.obs;

  final RxInt depositPercent = 30.obs;
  final RxInt cancellationDeductPercent = 20.obs;
  final RxInt minCancelHoursBefore = 1.obs;
  final RxString jazzCashNumber = '0300-0000000'.obs;

  StreamSubscription? _arenasSub;
  StreamSubscription? _boostsSub;
  StreamSubscription? _usersSub;
  StreamSubscription? _bookingsSub;
  StreamSubscription? _ticketsSub;

  // ── Live booking stats ─────────────────────────────────────────────────
  final RxList<BookingModel> _recentBookings = <BookingModel>[].obs;
  final RxInt openTickets = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _arenasSub = _arenaService
        .allArenas()
        .listen((list) => arenas.assignAll(list));
    _boostsSub = _boostService
        .allRequests()
        .listen((list) => boosts.assignAll(list));
    _usersSub = _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((s) => users.assignAll(
              s.docs
                  .map((d) => UserModel.fromMap({...d.data(), 'uid': d.id}))
                  .toList(),
            ));

    // Stream last 30 days of bookings for live stats — keep limit low.
    final since = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 30)));
    _bookingsSub = _db
        .collection('bookings')
        .where('createdAt', isGreaterThanOrEqualTo: since)
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .listen((s) => _recentBookings.assignAll(
              s.docs
                  .map((d) => BookingModel.fromMap({...d.data(), 'id': d.id}))
                  .toList(),
            ));

    _ticketsSub = _db
        .collection('tickets')
        .where('status', whereNotIn: ['resolved', 'closed'])
        .snapshots()
        .listen((s) => openTickets.value = s.docs.length);

    _loadSettings();
  }

  @override
  void onClose() {
    _arenasSub?.cancel();
    _boostsSub?.cancel();
    _usersSub?.cancel();
    _bookingsSub?.cancel();
    _ticketsSub?.cancel();
    super.onClose();
  }

  Future<void> _loadSettings() async {
    final doc = await _db.collection('settings').doc('booking').get();
    if (!doc.exists) return;
    final d = doc.data()!;
    depositPercent.value = (d['depositPercent'] ?? 30) as int;
    cancellationDeductPercent.value =
        (d['cancellationDeductPercent'] ?? 20) as int;
    minCancelHoursBefore.value = (d['minCancelHoursBefore'] ?? 1) as int;
    jazzCashNumber.value = d['jazzCashNumber'] ?? '0300-0000000';
    final verified = List<String>.from(d['verifiedArenaDocs'] ?? []);
    verifiedArenaDocs.assignAll(verified.toSet());
  }

  // ── Derived lists ─────────────────────────────────────────────────────

  List<ArenaModel> get pendingArenas =>
      arenas.where((a) => a.status == ArenaStatus.pending).toList();

  List<BoostRequestModel> get pendingBoosts =>
      boosts.where((b) => b.status == BoostStatus.pending).toList();

  List<BoostRequestModel> get activeBoosts =>
      boosts.where((b) => b.status == BoostStatus.approved).toList();

  // ── Arena management (via repository — auto-audited) ─────────────────

  Future<void> setArenaStatus(String id, ArenaStatus status,
      {String? reason}) async {
    final name = _arenaName(id);
    await _repo.setArenaStatus(id, status, name, reason: reason);
  }

  Future<void> toggleArenaActive(String id) async {
    final arena = arenas.firstWhereOrNull((a) => a.id == id);
    if (arena == null) return;
    await _repo.toggleArenaActive(id, arena.name, !arena.isActive);
  }

  Future<void> toggleFeatured(String arenaId, bool nextState) async {
    final name = _arenaName(arenaId);
    await _repo.toggleFeatured(arenaId, name, nextState);
  }

  void toggleDocsVerified(String id) {
    final name = _arenaName(id);
    final isVerified = verifiedArenaDocs.contains(id);
    if (isVerified) {
      verifiedArenaDocs.remove(id);
    } else {
      verifiedArenaDocs.add(id);
    }
    _repo.toggleDocsVerified(
        id, name, !isVerified, verifiedArenaDocs.toList());
  }

  Future<void> toggleCarousel(
    String arenaId, {
    required bool show,
    int? order,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final name = _arenaName(arenaId);
    final arena = arenas.firstWhereOrNull((a) => a.id == arenaId);
    await _repo.toggleCarousel(
      arenaId,
      name,
      show: show,
      order: order ?? arena?.carouselOrder,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> setCarouselOrder(String arenaId, int order) async {
    await _repo.setCarouselOrder(arenaId, order);
  }

  // ── Boost management ──────────────────────────────────────────────────

  Future<void> setBoostStatus(String id, BoostStatus status) async {
    final boost = boosts.firstWhereOrNull((b) => b.id == id);
    if (boost == null) return;
    await _repo.setBoostStatus(id, status, boost);
  }

  // ── User management ───────────────────────────────────────────────────

  Future<void> toggleBan(String uid) async {
    final user = users.firstWhereOrNull((u) => u.uid == uid);
    if (user == null) return;
    await _repo.toggleBan(user);
  }

  Future<void> changeRole(String uid, UserRole role) async {
    final user = users.firstWhereOrNull((u) => u.uid == uid);
    if (user == null) return;
    await _repo.changeRole(user, role);
  }

  // ── Owner invitations ─────────────────────────────────────────────────

  final _otp = OtpService();

  /// Live stream of all owner invitations, newest first.
  Stream<List<OwnerInvitationModel>> invitationsStream() => _db
      .collection('ownerInvitations')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => OwnerInvitationModel.fromMap(d.data(), d.id))
          .toList());

  Future<Map<String, dynamic>> inviteOwner({
    required String email,
    required String name,
    required String phone,
  }) async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    return _otp.inviteOwner(email: email, name: name, phone: phone, idToken: token!);
  }

  Future<void> resendInvitation(String invitationId) async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    await _otp.resendInvitation(invitationId, token!);
  }

  Future<void> revokeInvitation(String invitationId) async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    await _otp.revokeInvitation(invitationId, token!);
  }

  // ── Platform settings ─────────────────────────────────────────────────

  Future<void> saveSettings({
    required int deposit,
    required int deduct,
    required int minHours,
    required String jazzCash,
  }) async {
    final oldValues = {
      'depositPercent': depositPercent.value,
      'cancellationDeductPercent': cancellationDeductPercent.value,
      'minCancelHoursBefore': minCancelHoursBefore.value,
      'jazzCashNumber': jazzCashNumber.value,
    };
    await _repo.saveSettings(
      deposit: deposit,
      deduct: deduct,
      minHours: minHours,
      jazzCash: jazzCash,
      oldValues: oldValues,
    );
    depositPercent.value = deposit;
    cancellationDeductPercent.value = deduct;
    minCancelHoursBefore.value = minHours;
    jazzCashNumber.value = jazzCash;
  }

  // ── Notifications (in-memory; FCM broadcast in Phase 2) ──────────────

  int get unreadNotifications =>
      notifications.where((n) => !n.isRead).length;

  void markAllNotificationsRead() {
    for (var i = 0; i < notifications.length; i++) {
      notifications[i] = notifications[i].copyWith(isRead: true);
    }
  }

  // ── Dashboard stats ───────────────────────────────────────────────────

  int get totalArenas => arenas.length;
  int get totalUsers => users.length;
  int get totalOwners =>
      users.where((u) => u.role == UserRole.owner).length;
  int get totalStaff =>
      users.where((u) => u.role.isAdminTier && u.role != UserRole.admin).length;

  // ── Live stats derived from streams (auto-update with no extra reads) ──

  int get totalBookings => _recentBookings.length;

  int get todaysBookings {
    final today = DateTime.now();
    return _recentBookings.where((b) {
      return b.createdAt.year == today.year &&
          b.createdAt.month == today.month &&
          b.createdAt.day == today.day;
    }).length;
  }

  int get activeBookings =>
      _recentBookings.where((b) => b.status == BookingStatus.confirmed).length;

  int get completedBookings =>
      _recentBookings.where((b) => b.status == BookingStatus.completed).length;

  int get cancelledBookings =>
      _recentBookings.where((b) => b.isCancelled).length;

  double get monthlyRevenue => _recentBookings
      .where((b) => b.status == BookingStatus.completed)
      .fold(0.0, (sum, b) => sum + b.totalAmount);

  double get platformRevenue => monthlyRevenue * 0.10;

  UserModel? ownerOf(String ownerId) =>
      users.firstWhereOrNull((u) => u.uid == ownerId);

  String _arenaName(String id) =>
      arenas.firstWhereOrNull((a) => a.id == id)?.name ?? id;
}
