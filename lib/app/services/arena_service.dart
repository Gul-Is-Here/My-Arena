import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
    await ref.set({
      ...arena.toMap(),
      'id': ref.id,
      'status': 'pending',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateArena(String arenaId, Map<String, dynamic> data) =>
      _arenas.doc(arenaId).update(data);

  Future<void> deleteArena(String arenaId) =>
      _arenas.doc(arenaId).delete();

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

  /// Owner's own arenas.
  Stream<List<ArenaModel>> ownerArenas(String ownerId) => _arenas
      .where('ownerId', isEqualTo: ownerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => ArenaModel.fromMap({...d.data(), 'id': d.id}))
          .toList());

  /// Customer discovery — approved + active arenas.
  Stream<List<ArenaModel>> approvedArenas() => _arenas
      .where('status', isEqualTo: 'approved')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => ArenaModel.fromMap({...d.data(), 'id': d.id}))
          .toList());

  /// Toggle arena ON/OFF.
  Future<void> toggleActive(String arenaId, bool isActive) =>
      _arenas.doc(arenaId).update({'isActive': isActive});

  /// All arenas — admin stream.
  Stream<List<ArenaModel>> allArenas() => _arenas
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => ArenaModel.fromMap({...d.data(), 'id': d.id}))
          .toList());

  /// Admin: set arena approval status.
  Future<void> setStatus(String arenaId, ArenaStatus status) =>
      _arenas.doc(arenaId).update({'status': status.name});

  // ── Courts ───────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _courts(String arenaId) =>
      _arenas.doc(arenaId).collection('courts');

  Future<void> addCourt(String arenaId, CourtModel court) async {
    final ref = _courts(arenaId).doc();
    await ref.set({...court.toMap(), 'id': ref.id, 'arenaId': arenaId});
  }

  Future<void> updateCourt(
          String arenaId, String courtId, Map<String, dynamic> data) =>
      _courts(arenaId).doc(courtId).update(data);

  Future<void> deleteCourt(String arenaId, String courtId) =>
      _courts(arenaId).doc(courtId).delete();

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

  /// Uploads a list of local image files and returns their download URLs.
  Future<List<String>> uploadArenaImages(
      String arenaId, List<File> files) async {
    final urls = <String>[];
    for (int i = 0; i < files.length; i++) {
      final ref = _storage
          .ref('arenas/$arenaId/images/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
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
      _favorites(uid).doc(arenaId).set({'savedAt': FieldValue.serverTimestamp()});

  Future<void> removeFavorite(String uid, String arenaId) =>
      _favorites(uid).doc(arenaId).delete();

  // ── Reviews ───────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _reviews(String arenaId) =>
      _arenas.doc(arenaId).collection('reviews');

  /// Submit a review for an arena and mark the booking as reviewed.
  Future<void> submitReview(ReviewModel review) async {
    final ref = _reviews(review.arenaId).doc();
    final batch = _db.batch();
    batch.set(ref, {...review.toMap(), 'id': ref.id});
    // Mark the source booking so the "Rate" button disappears
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
    final snap =
        await _reviews(arenaId).orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs
        .map((d) => ReviewModel.fromMap({...d.data(), 'id': d.id}))
        .toList();
  }
}
