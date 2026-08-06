import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../data/models/arena_model.dart';
import '../data/models/court_model.dart';
import '../data/models/review_model.dart';

/// Firestore + Storage operations for arenas and courts.
class ArenaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _arenas =>
      _db.collection('arenas');

  // ── Arena CRUD ───────────────────────────────────────────────────────

  Future<String> createArena(ArenaModel arena) async {
    final ref = _arenas.doc();
    final data = <String, dynamic>{
      ...arena.toMap(),
      'id': ref.id,
      'status': 'pending',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    };
    // Store geohash so geo-radius queries work immediately after approval.
    if (arena.location.lat != 0 || arena.location.lng != 0) {
      final geoPoint =
          GeoFirePoint(GeoPoint(arena.location.lat, arena.location.lng));
      data['position'] = geoPoint.data;
    }
    await ref.set(data);
    return ref.id;
  }

  Future<void> updateArena(String arenaId, Map<String, dynamic> data) async {
    // Sync geohash whenever location is updated.
    if (data.containsKey('location')) {
      final loc = data['location'] as Map<String, dynamic>?;
      final lat = ((loc?['lat']) ?? 0).toDouble();
      final lng = ((loc?['lng']) ?? 0).toDouble();
      if (lat != 0 || lng != 0) {
        data['position'] =
            GeoFirePoint(GeoPoint(lat, lng)).data;
      }
    }
    await _arenas.doc(arenaId).update(data);
  }

  Future<void> deleteArena(String arenaId) async {
    final courtsSnap = await _courts(arenaId).get();
    final batch = _db.batch();
    for (final doc in courtsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_arenas.doc(arenaId));
    await batch.commit();

    try {
      final imagesList = await _storage.ref('arenas/$arenaId/images').listAll();
      await Future.wait(imagesList.items.map((ref) => ref.delete()));
    } catch (_) {}
  }

  Future<ArenaModel?> fetchArena(String arenaId) async {
    final doc = await _arenas.doc(arenaId).get();
    if (!doc.exists) return null;
    return ArenaModel.fromMap({...doc.data()!, 'id': doc.id});
  }

  Stream<ArenaModel?> streamArena(String arenaId) => _arenas
      .doc(arenaId)
      .snapshots()
      .map((doc) => doc.exists
          ? ArenaModel.fromMap({...doc.data()!, 'id': doc.id})
          : null);

  /// Fetch a set of arenas by their IDs — used by arena staff who don't own them.
  Future<List<ArenaModel>> arenasByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final docs =
        await Future.wait(ids.map((id) => _arenas.doc(id).get()));
    return docs
        .where((d) => d.exists)
        .map((d) => ArenaModel.fromMap({...d.data()!, 'id': d.id}))
        .toList();
  }

  /// Arena staff: live stream of arenas whose IDs are in [ids].
  /// Uses FieldPath.documentId whereIn so only the assigned arena docs are sent.
  Stream<List<ArenaModel>> staffArenas(List<String> ids) {
    if (ids.isEmpty) return Stream.value([]);
    // Firestore whereIn cap is 30; take first 30 assigned arenas.
    final capped = ids.take(30).toList();
    return _arenas
        .where(FieldPath.documentId, whereIn: capped)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ArenaModel.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  /// Owner's own arenas. Courts are NOT pre-loaded — UI reads from courtSummary.
  Stream<List<ArenaModel>> ownerArenas(String ownerId) => _arenas
      .where('ownerId', isEqualTo: ownerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => ArenaModel.fromMap({...d.data(), 'id': d.id}))
          .toList());

  /// Geo-stream: approved + active arenas within [radiusKm] of [lat]/[lng].
  /// Uses Geohash range queries (geoflutterfire_plus) — no N+1 courts fetch.
  /// Status and isActive are filtered client-side because Firestore does not
  /// allow combining geohash range queries with additional equality filters.
  Stream<List<ArenaModel>> nearbyArenas(
      double lat, double lng, double radiusKm) {
    final center = GeoFirePoint(GeoPoint(lat, lng));
    final geoRef =
        GeoCollectionReference<Map<String, dynamic>>(_arenas);
    return geoRef
        .subscribeWithin(
          center: center,
          radiusInKm: radiusKm,
          field: 'position',
          geopointFrom: (data) =>
              (data['position'] as Map<String, dynamic>)['geopoint'] as GeoPoint,
          strictMode: true,
        )
        .map((docs) => docs
            .where((d) {
              final data = d.data();
              return data != null &&
                  data['status'] == 'approved' &&
                  data['isActive'] == true;
            })
            .map((d) => ArenaModel.fromMap({...d.data()!, 'id': d.id}))
            .toList());
  }

  /// Cursor-based page fetch — fallback when location is unavailable.
  /// Returns a record: the arena list and the last document (cursor for next page).
  Future<({List<ArenaModel> arenas, DocumentSnapshot? cursor})> fetchArenaPage({
    DocumentSnapshot? after,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> q = _arenas
        .where('status', isEqualTo: 'approved')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (after != null) q = q.startAfterDocument(after);
    final snap = await q.get();
    return (
      arenas: snap.docs
          .map((d) => ArenaModel.fromMap({...d.data(), 'id': d.id}))
          .toList(),
      cursor: snap.docs.isEmpty ? null : snap.docs.last,
    );
  }

  /// Toggle arena ON/OFF.
  Future<void> toggleActive(String arenaId, bool isActive) =>
      _arenas.doc(arenaId).update({'isActive': isActive});

  /// Admin-curated home carousel arenas, sorted by carouselOrder.
  Stream<List<ArenaModel>> carouselArenas() => _arenas
      .where('showOnHomeCarousel', isEqualTo: true)
      .where('status', isEqualTo: 'approved')
      .where('isActive', isEqualTo: true)
      .orderBy('carouselOrder')
      .snapshots()
      .map((s) {
    final now = DateTime.now();
    return s.docs
        .map((d) => ArenaModel.fromMap({...d.data(), 'id': d.id}))
        .where((a) {
          if (a.carouselStartDate != null && now.isBefore(a.carouselStartDate!)) return false;
          if (a.carouselEndDate != null && now.isAfter(a.carouselEndDate!)) return false;
          return true;
        })
        .toList();
  });

  /// All arenas — admin stream.
  Stream<List<ArenaModel>> allArenas() => _arenas
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => ArenaModel.fromMap({...d.data(), 'id': d.id}))
          .toList());

  /// Admin: set arena approval status.
  Future<void> setStatus(
    String arenaId,
    ArenaStatus status, {
    String? rejectionReason,
    String? rejectedBy,
  }) {
    final data = <String, dynamic>{'status': status.name};
    if (status == ArenaStatus.rejected) {
      data['rejectionReason'] = rejectionReason ?? '';
      data['rejectedBy'] = rejectedBy ?? '';
      data['rejectedAt'] = FieldValue.serverTimestamp();
    } else if (status == ArenaStatus.approved) {
      data['rejectionReason'] = FieldValue.delete();
      data['rejectedBy'] = FieldValue.delete();
      data['rejectedAt'] = FieldValue.delete();
    }
    return _arenas.doc(arenaId).update(data);
  }

  // ── Courts ───────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _courts(String arenaId) =>
      _arenas.doc(arenaId).collection('courts');

  Future<void> addCourt(String arenaId, CourtModel court) async {
    final ref = _courts(arenaId).doc();
    await ref.set({...court.toMap(), 'id': ref.id, 'arenaId': arenaId});
    await syncCourtSummary(arenaId);
  }

  Future<void> updateCourt(
      String arenaId, String courtId, Map<String, dynamic> data) async {
    await _courts(arenaId).doc(courtId).update(data);
    await syncCourtSummary(arenaId);
  }

  Future<void> deleteCourt(String arenaId, String courtId) async {
    await _courts(arenaId).doc(courtId).delete();
    await syncCourtSummary(arenaId);
  }

  /// Recomputes courtSummary from active courts and writes it to the arena doc.
  /// Called automatically after every court write so discovery never needs
  /// to fetch the courts subcollection.
  Future<void> syncCourtSummary(String arenaId) async {
    final snap = await _courts(arenaId).get();
    final active = snap.docs
        .map((d) => CourtModel.fromMap({...d.data(), 'id': d.id}))
        .where((c) => c.isActive)
        .toList();
    await _arenas.doc(arenaId).update({
      'courtSummary': {
        'courtCount': active.length,
        'minPrice': active.isEmpty
            ? 0.0
            : active.map((c) => c.pricePerHour).reduce(min),
        'sportTypes': active.map((c) => c.type.name).toSet().toList(),
        'surfaces': active.map((c) => c.surface.name).toSet().toList(),
        'amenities': active
            .expand((c) => c.amenities.map((a) => a.name))
            .toSet()
            .toList(),
      }
    });
  }

  /// One-time fetch of every court (active or not) — used by the edit flow.
  Future<List<CourtModel>> fetchAllCourts(String arenaId) async {
    final snap = await _courts(arenaId).get();
    return snap.docs
        .map((d) => CourtModel.fromMap({...d.data(), 'id': d.id}))
        .toList();
  }

  Stream<List<CourtModel>> courts(String arenaId) => _courts(arenaId)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => CourtModel.fromMap({...d.data(), 'id': d.id}))
          .toList());

  // ── Firebase Storage — images ─────────────────────────────────────────

  Future<List<String>> uploadArenaImages(
      String arenaId, List<File> files) async {
    final urls = <String>[];
    for (int i = 0; i < files.length; i++) {
      final ref = _storage.ref(
          'arenas/$arenaId/images/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
      await ref.putFile(files[i]);
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<String> uploadCourtImage(
      String arenaId, String courtId, File file) async {
    final ref = _storage.ref(
        'arenas/$arenaId/courts/$courtId/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  // ── Favorites ─────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _favorites(String uid) =>
      _db.collection('users').doc(uid).collection('favorites');

  Stream<Set<String>> favoritesStream(String uid) => _favorites(uid)
      .snapshots()
      .map((s) => s.docs.map((d) => d.id).toSet());

  Future<void> addFavorite(String uid, String arenaId) =>
      _favorites(uid)
          .doc(arenaId)
          .set({'savedAt': FieldValue.serverTimestamp()});

  Future<void> removeFavorite(String uid, String arenaId) =>
      _favorites(uid).doc(arenaId).delete();

  // ── Reviews ───────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _reviews(String arenaId) =>
      _arenas.doc(arenaId).collection('reviews');

  Future<void> submitReview(ReviewModel review) async {
    final ref = _reviews(review.arenaId).doc();
    final batch = _db.batch();
    batch.set(ref, {...review.toMap(), 'id': ref.id});
    batch.update(
      _db.collection('bookings').doc(review.bookingId),
      {'hasReview': true},
    );
    await batch.commit();
  }

  Stream<List<ReviewModel>> reviewStream(String arenaId) =>
      _reviews(arenaId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map((d) => ReviewModel.fromMap({...d.data(), 'id': d.id}))
              .toList());

  Future<List<ReviewModel>> fetchReviews(String arenaId,
      {int limit = 20}) async {
    final snap = await _reviews(arenaId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => ReviewModel.fromMap({...d.data(), 'id': d.id}))
        .toList();
  }
}
