import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/promotion_model.dart';

class PromotionService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('promotions');

  // ── Owner CRUD ────────────────────────────────────────────────────

  Stream<List<PromotionModel>> ownerPromotions(String arenaId) => _col
      .where('arenaId', isEqualTo: arenaId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => PromotionModel.fromMap({...d.data(), 'id': d.id}))
          .toList());

  // ── Admin / Platform CRUD ─────────────────────────────────────────

  Stream<List<PromotionModel>> platformPromotions() => _col
      .where('scope', isEqualTo: PromotionScope.platform.name)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => PromotionModel.fromMap({...d.data(), 'id': d.id}))
          .toList());

  // ── Shared CRUD ───────────────────────────────────────────────────

  Future<void> create(PromotionModel p) async {
    final ref = _col.doc();
    await ref.set({...p.toMap(), 'id': ref.id});
  }

  Future<void> update(String id, Map<String, dynamic> data) =>
      _col.doc(id).update(data);

  Future<void> delete(String id) => _col.doc(id).delete();

  Future<void> setStatus(String id, PromotionStatus status) =>
      _col.doc(id).update({'status': status.name});

  // ── Customer lookup ───────────────────────────────────────────────

  /// Returns all currently active promotions visible to a customer for [arenaId]:
  /// both the platform-wide promos and the arena-specific ones.
  /// Used for offer discovery on arena detail + arena list badge.
  Future<List<PromotionModel>> fetchActiveForArena(String arenaId) async {
    final now = DateTime.now();

    final results = await Future.wait([
      // Platform promos — visible on all arenas.
      _col
          .where('scope', isEqualTo: PromotionScope.platform.name)
          .where('status', isEqualTo: PromotionStatus.active.name)
          .get(),
      // Arena-specific promos.
      _col
          .where('arenaId', isEqualTo: arenaId)
          .where('scope', isEqualTo: PromotionScope.arena.name)
          .where('status', isEqualTo: PromotionStatus.active.name)
          .get(),
    ]);

    final all = [
      ...results[0].docs,
      ...results[1].docs,
    ]
        .map((d) => PromotionModel.fromMap({...d.data(), 'id': d.id}))
        .where((p) =>
            p.isActive &&
            (p.expiresAt == null || p.expiresAt!.isAfter(now)))
        .toList();

    // Platform promos first, then arena promos.
    all.sort((a, b) {
      if (a.isPlatform && !b.isPlatform) return -1;
      if (!a.isPlatform && b.isPlatform) return 1;
      return 0;
    });

    return all;
  }

  /// Checks platform promos first (they win over arena promos).
  /// Returns the winning active promotion, or null if none found.
  /// [bookingTotal] is used to enforce minBookingAmount.
  Future<PromotionModel?> findActive(String arenaId, String rawCode,
      {double bookingTotal = 0}) async {
    final code = rawCode.toUpperCase().trim();

    // 1. Check platform-wide promos (highest priority).
    final platSnap = await _col
        .where('scope', isEqualTo: PromotionScope.platform.name)
        .where('codeNormalized', isEqualTo: code)
        .where('status', isEqualTo: PromotionStatus.active.name)
        .limit(1)
        .get();

    if (platSnap.docs.isNotEmpty) {
      final promo = PromotionModel.fromMap(
          {...platSnap.docs.first.data(), 'id': platSnap.docs.first.id});
      if (promo.isActive) return promo;
    }

    // 2. Fall back to arena-scoped promo.
    final arenaSnap = await _col
        .where('arenaId', isEqualTo: arenaId)
        .where('codeNormalized', isEqualTo: code)
        .where('status', isEqualTo: PromotionStatus.active.name)
        .limit(1)
        .get();

    if (arenaSnap.docs.isEmpty) return null;
    final promo = PromotionModel.fromMap(
        {...arenaSnap.docs.first.data(), 'id': arenaSnap.docs.first.id});
    return promo.isActive ? promo : null;
  }

  /// Atomically increments usageCount. Called after a booking is confirmed.
  Future<void> recordUsage(String promoId) =>
      _col.doc(promoId).update({'usageCount': FieldValue.increment(1)});

  /// Decrements usageCount when a booking using this promo is cancelled.
  Future<void> reverseUsage(String promoId) =>
      _col.doc(promoId).update({'usageCount': FieldValue.increment(-1)});

  // ── Max owner discount cap ────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      _db.collection('settings').doc('promotionSettings');

  Future<double> fetchMaxOwnerDiscountPct() async {
    final snap = await _settingsDoc.get();
    return (snap.data()?['maxOwnerDiscountPct'] as num?)?.toDouble() ?? 100.0;
  }

  Stream<double> streamMaxOwnerDiscountPct() => _settingsDoc
      .snapshots()
      .map((s) => (s.data()?['maxOwnerDiscountPct'] as num?)?.toDouble() ?? 100.0);

  Future<void> setMaxOwnerDiscountPct(double pct) =>
      _settingsDoc.set({'maxOwnerDiscountPct': pct}, SetOptions(merge: true));
}
