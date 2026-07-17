import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/tournament_model.dart';
import '../services/tournament_service.dart';

class TournamentController extends GetxController {
  static TournamentController get to => Get.find();

  final _service = TournamentService();
  final _picker = ImagePicker();

  String get myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  final RxList<TournamentModel> tournaments = <TournamentModel>[].obs;

  /// My registrations (current user).
  final RxList<RegistrationModel> myRegistrations = <RegistrationModel>[].obs;

  /// Per-tournament registrations: streamed on demand when a tournament is opened.
  final Map<String, RxList<RegistrationModel>> _tournamentRegs = {};
  final Map<String, StreamSubscription> _regSubs = {};

  /// Bracket data: tournamentId → rounds (live from Firestore).
  final RxMap<String, List<BracketRound>> brackets =
      <String, List<BracketRound>>{}.obs;
  final Map<String, StreamSubscription> _bracketSubs = {};

  StreamSubscription? _tournamentsSub;
  StreamSubscription? _myRegsSub;

  // ── Lifecycle ──────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _tournamentsSub = _service.publicTournaments().listen(
          (list) => tournaments.assignAll(list),
        );
    if (myUid.isNotEmpty) {
      _myRegsSub = _service
          .userRegistrations(myUid)
          .listen((list) => myRegistrations.assignAll(list));
    }
  }

  @override
  void onClose() {
    _tournamentsSub?.cancel();
    _myRegsSub?.cancel();
    for (final s in _regSubs.values) {
      s.cancel();
    }
    for (final s in _bracketSubs.values) {
      s.cancel();
    }
    super.onClose();
  }

  // ── Admin/owner tournament stream ─────────────────────────────────

  void listenAllTournaments() {
    _tournamentsSub?.cancel();
    _tournamentsSub = _service
        .allTournaments()
        .listen((list) => tournaments.assignAll(list));
  }

  void listenOwnerTournaments() {
    _tournamentsSub?.cancel();
    _tournamentsSub = _service
        .ownerTournaments(myUid)
        .listen((list) => tournaments.assignAll(list));
  }

  // ── Per-tournament registrations ───────────────────────────────────

  RxList<RegistrationModel> registrationsList(String tournamentId) {
    if (!_tournamentRegs.containsKey(tournamentId)) {
      _tournamentRegs[tournamentId] = <RegistrationModel>[].obs;
      _regSubs[tournamentId] = _service
          .registrationsFor(tournamentId, myUid: myUid)
          .listen((list) => _tournamentRegs[tournamentId]!.assignAll(list));
    }
    return _tournamentRegs[tournamentId]!;
  }

  // ── Queries ────────────────────────────────────────────────────────

  List<TournamentModel> get publicTournaments => tournaments
      .where((t) =>
          t.status == TournamentStatus.registrationOpen ||
          t.status == TournamentStatus.ongoing ||
          t.status == TournamentStatus.completed)
      .toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));

  List<TournamentModel> get ownerTournaments =>
      tournaments.where((t) => t.createdBy == myUid).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<TournamentModel> get pendingApproval => tournaments
      .where((t) => t.status == TournamentStatus.pendingApproval)
      .toList();

  TournamentModel? byId(String id) =>
      tournaments.firstWhereOrNull((t) => t.id == id);

  List<RegistrationModel> registrationsFor(String tournamentId) =>
      registrationsList(tournamentId);

  bool isRegistered(String tournamentId) =>
      myRegistrations.any((r) => r.tournamentId == tournamentId);

  // ── Tournament CRUD ────────────────────────────────────────────────

  Future<void> create(TournamentModel t, {File? banner}) async {
    await _service.createTournament(t, banner: banner);
  }

  Future<void> setStatus(String id, TournamentStatus status) async {
    await _service.updateStatus(id, status);
    final i = tournaments.indexWhere((t) => t.id == id);
    if (i != -1) {
      tournaments[i] = tournaments[i].copyWith(status: status);
    }
  }

  // ── Registration ───────────────────────────────────────────────────

  Future<void> register(RegistrationModel reg, {File? paymentScreenshot}) async {
    await _service.createRegistration(reg, paymentScreenshot: paymentScreenshot);
  }

  Future<void> verifyPayment(String regId) async {
    await _service.verifyPayment(regId);
  }

  Future<void> rejectRegistration(String regId) async {
    await _service.rejectRegistration(regId);
  }

  // ── Bracket ────────────────────────────────────────────────────────

  void listenBracket(String tournamentId) {
    if (_bracketSubs.containsKey(tournamentId)) return;
    _bracketSubs[tournamentId] =
        _service.bracketStream(tournamentId).listen((rounds) {
      if (rounds != null) {
        brackets[tournamentId] = rounds;
        brackets.refresh();
      }
    });
  }

  Future<void> generateBracket(String tournamentId) async {
    final t = byId(tournamentId);
    if (t == null) return;
    final regs = registrationsList(tournamentId);
    final names = regs
        .where((r) => r.status == 'confirmed')
        .map((r) => r.playerName)
        .toList()
      ..shuffle(Random());
    if (names.length < 2) {
      Get.snackbar('Not enough players',
          'At least 2 confirmed participants needed.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
      return;
    }

    List<BracketRound> rounds;
    if (t.format == TournamentFormat.elimination) {
      rounds = _eliminationRounds(tournamentId, names);
    } else {
      rounds = [
        BracketRound(
          roundNumber: 1,
          matches: [
            for (var i = 0; i < names.length; i++)
              for (var j = i + 1; j < names.length; j++)
                MatchModel(
                  id: '$tournamentId-rr-$i-$j',
                  participant1: names[i],
                  participant2: names[j],
                ),
          ],
        ),
      ];
    }

    brackets[tournamentId] = rounds;
    brackets.refresh();
    await _service.saveBracket(tournamentId, rounds);
    await setStatus(tournamentId, TournamentStatus.ongoing);
  }

  List<BracketRound> _eliminationRounds(String tid, List<String> names) {
    var size = 2;
    while (size < names.length) {
      size *= 2;
    }
    final slots = List<String?>.from(names)
      ..addAll(List.filled(size - names.length, null));

    final rounds = <BracketRound>[];
    var matchCount = size ~/ 2;
    var roundNum = 1;
    while (matchCount >= 1) {
      final matches = <MatchModel>[];
      if (rounds.isEmpty) {
        for (var i = 0; i < slots.length; i += 2) {
          matches.add(MatchModel(
            id: '$tid-r1-${i ~/ 2}',
            participant1: slots[i],
            participant2: slots[i + 1],
            status: slots[i] == null || slots[i + 1] == null
                ? 'completed'
                : 'scheduled',
          ));
        }
      } else {
        for (var i = 0; i < matchCount; i++) {
          matches.add(MatchModel(id: '$tid-r$roundNum-$i'));
        }
      }
      rounds.add(BracketRound(roundNumber: roundNum, matches: matches));
      matchCount ~/= 2;
      roundNum++;
    }
    return rounds;
  }

  void _advance(List<BracketRound> rounds, int roundIdx, int matchIdx,
      String winner) {
    if (roundIdx + 1 >= rounds.length) return;
    final next = rounds[roundIdx + 1].matches[matchIdx ~/ 2];
    rounds[roundIdx + 1].matches[matchIdx ~/ 2] = matchIdx.isEven
        ? next.copyWith(participant1: winner)
        : next.copyWith(participant2: winner);
  }

  Future<void> enterScore(String tournamentId, int roundIdx, int matchIdx,
      int s1, int s2) async {
    final rounds = brackets[tournamentId];
    final t = byId(tournamentId);
    if (rounds == null || t == null) return;

    final match = rounds[roundIdx].matches[matchIdx]
        .copyWith(score1: s1, score2: s2, status: 'completed');
    rounds[roundIdx].matches[matchIdx] = match;

    if (t.format == TournamentFormat.elimination && match.winner != null) {
      _advance(rounds, roundIdx, matchIdx, match.winner!);
      if (roundIdx == rounds.length - 1) {
        await setStatus(tournamentId, TournamentStatus.completed);
      }
    } else if (t.format == TournamentFormat.roundRobin) {
      final allDone =
          rounds.first.matches.every((m) => m.status == 'completed');
      if (allDone) await setStatus(tournamentId, TournamentStatus.completed);
    }
    brackets.refresh();
    await _service.updateMatch(tournamentId, rounds);
  }

  // ── Leaderboard (round robin) ──────────────────────────────────────

  List<LeaderboardEntry> leaderboard(String tournamentId) {
    final rounds = brackets[tournamentId];
    if (rounds == null) return [];
    final stats = <String, List<int>>{};

    for (final m in rounds.first.matches) {
      if (m.participant1 == null || m.participant2 == null) continue;
      stats.putIfAbsent(m.participant1!, () => [0, 0, 0, 0]);
      stats.putIfAbsent(m.participant2!, () => [0, 0, 0, 0]);
      if (m.status != 'completed') continue;
      stats[m.participant1]![0]++;
      stats[m.participant2]![0]++;
      if (m.score1 == m.score2) {
        stats[m.participant1]![3]++;
        stats[m.participant2]![3]++;
      } else if (m.winner == m.participant1) {
        stats[m.participant1]![1]++;
        stats[m.participant2]![2]++;
      } else {
        stats[m.participant2]![1]++;
        stats[m.participant1]![2]++;
      }
    }

    return stats.entries
        .map((e) => LeaderboardEntry(
              name: e.key,
              played: e.value[0],
              won: e.value[1],
              lost: e.value[2],
              drawn: e.value[3],
              points: e.value[1] * 3 + e.value[3],
            ))
        .toList()
      ..sort((a, b) => b.points.compareTo(a.points));
  }

  // ── Banner picker (for create screen) ─────────────────────────────

  Future<XFile?> pickBanner() => _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
}
