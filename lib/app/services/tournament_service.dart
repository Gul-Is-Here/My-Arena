import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../data/models/tournament_model.dart';

class TournamentService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('tournaments');
  CollectionReference<Map<String, dynamic>> get _regs =>
      _db.collection('registrations');
  CollectionReference<Map<String, dynamic>> get _brackets =>
      _db.collection('brackets');

  // ── Tournament streams ───────────────────────────────────────────────

  Stream<List<TournamentModel>> allTournaments() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(_mapTournaments);

  Stream<List<TournamentModel>> publicTournaments() => _col
      .where('status', whereIn: [
        'registration_open',
        'ongoing',
        'completed',
      ])
      .orderBy('startDate')
      .snapshots()
      .map(_mapTournaments);

  Stream<List<TournamentModel>> ownerTournaments(String ownerId) => _col
      .where('createdBy', isEqualTo: ownerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(_mapTournaments);

  Stream<List<TournamentModel>> pendingApproval() => _col
      .where('status', isEqualTo: 'pending_approval')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(_mapTournaments);

  List<TournamentModel> _mapTournaments(
          QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs
          .map((d) => TournamentModel.fromMap({...d.data(), 'id': d.id}))
          .toList();

  // ── Tournament writes ────────────────────────────────────────────────

  Future<String> createTournament(TournamentModel t, {File? banner}) async {
    final ref = _col.doc();
    String bannerUrl = '';
    if (banner != null) {
      final sRef = _storage.ref('tournaments/${ref.id}/banner.jpg');
      await sRef.putFile(banner);
      bannerUrl = await sRef.getDownloadURL();
    }
    await ref.set({...t.toMap(), 'id': ref.id, 'bannerImage': bannerUrl});
    return ref.id;
  }

  Future<void> updateStatus(String id, TournamentStatus status) =>
      _col.doc(id).update({'status': status.key});

  Future<void> incrementRegisteredCount(String tournamentId) =>
      _col.doc(tournamentId).update({
        'registeredCount': FieldValue.increment(1),
      });

  // ── Registrations ────────────────────────────────────────────────────

  Stream<List<RegistrationModel>> registrationsFor(String tournamentId,
          {String myUid = ''}) =>
      _regs
          .where('tournamentId', isEqualTo: tournamentId)
          .orderBy('registeredAt', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map((d) => RegistrationModel.fromMap(
                  {...d.data(), 'id': d.id},
                  myUid: myUid))
              .toList());

  Stream<List<RegistrationModel>> userRegistrations(String uid) => _regs
      .where('userId', isEqualTo: uid)
      .orderBy('registeredAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => RegistrationModel.fromMap(
              {...d.data(), 'id': d.id},
              myUid: uid))
          .toList());

  Future<String> createRegistration(RegistrationModel reg,
      {File? paymentScreenshot}) async {
    final ref = _regs.doc();
    String screenshotUrl = '';
    if (paymentScreenshot != null) {
      final sRef = _storage.ref(
          'registrations/${ref.id}/payment_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await sRef.putFile(paymentScreenshot);
      screenshotUrl = await sRef.getDownloadURL();
    }
    await ref.set({
      ...reg.toMap(),
      'id': ref.id,
      if (screenshotUrl.isNotEmpty) 'paymentScreenshot': screenshotUrl,
    });
    await incrementRegisteredCount(reg.tournamentId);
    return ref.id;
  }

  Future<void> verifyPayment(String regId) => _regs.doc(regId).update({
        'paymentStatus': 'verified',
        'status': 'confirmed',
      });

  Future<void> rejectRegistration(String regId) =>
      _regs.doc(regId).update({'status': 'rejected'});

  // ── Brackets ─────────────────────────────────────────────────────────

  Stream<List<BracketRound>?> bracketStream(String tournamentId) =>
      _brackets.doc(tournamentId).snapshots().map((snap) {
        if (!snap.exists) return null;
        final rounds = snap.data()?['rounds'] as List<dynamic>?;
        if (rounds == null) return null;
        return rounds
            .map((r) => BracketRound.fromMap(Map<String, dynamic>.from(r)))
            .toList();
      });

  Future<void> saveBracket(
      String tournamentId, List<BracketRound> rounds) async {
    await _brackets.doc(tournamentId).set({
      'tournamentId': tournamentId,
      'rounds': rounds.map((r) => r.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMatch(String tournamentId, List<BracketRound> rounds) =>
      saveBracket(tournamentId, rounds);
}
