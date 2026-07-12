import 'dart:math';

import 'package:get/get.dart';

import '../data/models/tournament_model.dart';

/// Tournament state for all roles — dummy data in the UI-first phase.
/// Bracket generation, winner advancement and points tables run
/// client-side here and move to Cloud Functions later.
class TournamentController extends GetxController {
  static TournamentController get to => Get.find();

  final RxList<TournamentModel> tournaments = <TournamentModel>[].obs;
  final RxList<RegistrationModel> registrations = <RegistrationModel>[].obs;

  /// tournamentId → rounds. Only exists once a bracket is generated.
  final RxMap<String, List<BracketRound>> brackets =
      <String, List<BracketRound>>{}.obs;

  // ── Queries ────────────────────────────────────────────────────────
  List<TournamentModel> get publicTournaments => tournaments
      .where((t) =>
          t.status == TournamentStatus.registrationOpen ||
          t.status == TournamentStatus.ongoing ||
          t.status == TournamentStatus.completed)
      .toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));

  List<TournamentModel> get ownerTournaments =>
      tournaments.where((t) => t.createdByRole == 'owner').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<TournamentModel> get pendingApproval => tournaments
      .where((t) => t.status == TournamentStatus.pendingApproval)
      .toList();

  List<RegistrationModel> get myRegistrations =>
      registrations.where((r) => r.isMine).toList()
        ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));

  TournamentModel? byId(String id) =>
      tournaments.firstWhereOrNull((t) => t.id == id);

  List<RegistrationModel> registrationsFor(String tournamentId) =>
      registrations.where((r) => r.tournamentId == tournamentId).toList();

  bool isRegistered(String tournamentId) =>
      registrations.any((r) => r.tournamentId == tournamentId && r.isMine);

  // ── Lifecycle ──────────────────────────────────────────────────────
  void create(TournamentModel t) => tournaments.insert(0, t);

  void setStatus(String id, TournamentStatus status) {
    final i = tournaments.indexWhere((t) => t.id == id);
    if (i == -1) return;
    tournaments[i] = tournaments[i].copyWith(status: status);
  }

  // ── Registration ───────────────────────────────────────────────────
  void register(RegistrationModel reg) {
    registrations.add(reg);
    final i = tournaments.indexWhere((t) => t.id == reg.tournamentId);
    if (i != -1) {
      tournaments[i] = tournaments[i]
          .copyWith(registeredCount: tournaments[i].registeredCount + 1);
    }
  }

  void verifyPayment(String regId) {
    final i = registrations.indexWhere((r) => r.id == regId);
    if (i == -1) return;
    registrations[i] =
        registrations[i].copyWith(paymentStatus: 'verified', status: 'confirmed');
  }

  // ── Bracket ────────────────────────────────────────────────────────
  /// Shuffles confirmed participants and builds the bracket, then moves
  /// the tournament to ongoing.
  void generateBracket(String tournamentId) {
    final t = byId(tournamentId);
    if (t == null) return;
    final names = registrationsFor(tournamentId)
        .where((r) => r.status == 'confirmed')
        .map((r) => r.playerName)
        .toList()
      ..shuffle(Random());
    if (names.length < 2) return;

    if (t.format == TournamentFormat.elimination) {
      brackets[tournamentId] = _eliminationRounds(tournamentId, names);
    } else {
      brackets[tournamentId] = [
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
    setStatus(tournamentId, TournamentStatus.ongoing);
  }

  List<BracketRound> _eliminationRounds(String tid, List<String> names) {
    // Pad to the next power of two with byes (null participants).
    var size = 2;
    while (size < names.length) {
      size *= 2;
    }
    final slots = List<String?>.from(names)
      ..addAll(List.filled(size - names.length, null));

    final rounds = <BracketRound>[];
    var matchCount = size ~/ 2;
    var round = 1;
    while (matchCount >= 1) {
      rounds.add(BracketRound(
        roundNumber: round,
        matches: [
          for (var m = 0; m < matchCount; m++)
            round == 1
                ? MatchModel(
                    id: '$tid-r1-m$m',
                    participant1: slots[m * 2],
                    participant2: slots[m * 2 + 1],
                  )
                : MatchModel(id: '$tid-r$round-m$m'),
        ],
      ));
      matchCount ~/= 2;
      round++;
    }

    // Auto-advance byes from round 1.
    for (var m = 0; m < rounds[0].matches.length; m++) {
      final match = rounds[0].matches[m];
      if (match.participant1 != null && match.participant2 == null) {
        _advance(rounds, 0, m, match.participant1!);
      } else if (match.participant1 == null && match.participant2 != null) {
        _advance(rounds, 0, m, match.participant2!);
      }
    }
    return rounds;
  }

  void _advance(
      List<BracketRound> rounds, int roundIdx, int matchIdx, String winner) {
    if (roundIdx + 1 >= rounds.length) return;
    final next = rounds[roundIdx + 1].matches[matchIdx ~/ 2];
    rounds[roundIdx + 1].matches[matchIdx ~/ 2] = matchIdx.isEven
        ? next.copyWith(participant1: winner)
        : next.copyWith(participant2: winner);
  }

  /// Records a score. In elimination the winner advances automatically;
  /// if the final completes, the tournament is marked completed.
  void enterScore(String tournamentId, int roundIdx, int matchIdx, int s1, int s2) {
    final rounds = brackets[tournamentId];
    final t = byId(tournamentId);
    if (rounds == null || t == null) return;

    final match = rounds[roundIdx].matches[matchIdx]
        .copyWith(score1: s1, score2: s2, status: 'completed');
    rounds[roundIdx].matches[matchIdx] = match;

    if (t.format == TournamentFormat.elimination && match.winner != null) {
      _advance(rounds, roundIdx, matchIdx, match.winner!);
      if (roundIdx == rounds.length - 1) {
        setStatus(tournamentId, TournamentStatus.completed);
      }
    } else if (t.format == TournamentFormat.roundRobin) {
      final allDone =
          rounds.first.matches.every((m) => m.status == 'completed');
      if (allDone) setStatus(tournamentId, TournamentStatus.completed);
    }
    brackets.refresh();
  }

  /// Round-robin points table (win 3, draw 1) sorted by points.
  List<LeaderboardEntry> leaderboard(String tournamentId) {
    final rounds = brackets[tournamentId];
    if (rounds == null) return [];
    final stats = <String, List<int>>{}; // name → [played, won, lost, drawn]

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

    final entries = stats.entries
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
    return entries;
  }

  @override
  void onInit() {
    super.onInit();
    _seed();
  }

  void _seed() {
    final now = DateTime.now();
    tournaments.addAll([
      TournamentModel(
        id: 'tour-1',
        createdBy: 'mock-login',
        createdByRole: 'owner',
        arenaId: 'arena-1',
        arenaName: 'Champions Arena',
        name: 'Lahore Padel Cup',
        description:
            'City-wide knockout padel championship. Winner takes the trophy plus cash prize.',
        sport: 'Padel',
        format: TournamentFormat.elimination,
        participationType: ParticipationType.individual,
        maxParticipants: 8,
        registeredCount: 8,
        registrationFee: 1500,
        startDate: now.add(const Duration(days: 3)),
        endDate: now.add(const Duration(days: 5)),
        registrationDeadline: now.add(const Duration(days: 2)),
        status: TournamentStatus.ongoing,
        prizeDetails: 'PKR 50,000 + trophy',
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      TournamentModel(
        id: 'tour-2',
        createdBy: 'mock-login',
        createdByRole: 'owner',
        arenaId: 'arena-1',
        arenaName: 'Champions Arena',
        name: 'Weekend Futsal League',
        description:
            'Round-robin futsal league over four weekends. All matches on FIFA-standard turf.',
        sport: 'Football',
        format: TournamentFormat.roundRobin,
        participationType: ParticipationType.team,
        maxParticipants: 6,
        registeredCount: 4,
        registrationFee: 0,
        startDate: now.add(const Duration(days: 9)),
        endDate: now.add(const Duration(days: 30)),
        registrationDeadline: now.add(const Duration(days: 7)),
        status: TournamentStatus.registrationOpen,
        prizeDetails: 'PKR 30,000 team prize',
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      TournamentModel(
        id: 'tour-3',
        createdBy: 'admin',
        createdByRole: 'admin',
        arenaName: 'Multiple venues',
        name: 'MyArena Cricket Championship',
        description:
            'Platform-wide T10 cricket championship across partner arenas.',
        sport: 'Cricket',
        format: TournamentFormat.elimination,
        participationType: ParticipationType.team,
        maxParticipants: 16,
        registeredCount: 3,
        registrationFee: 5000,
        startDate: now.add(const Duration(days: 20)),
        endDate: now.add(const Duration(days: 24)),
        registrationDeadline: now.add(const Duration(days: 15)),
        status: TournamentStatus.registrationOpen,
        prizeDetails: 'PKR 200,000 + medals',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      TournamentModel(
        id: 'tour-4',
        createdBy: 'mock-login',
        createdByRole: 'owner',
        arenaId: 'arena-2',
        arenaName: 'Victory Sports Club',
        name: 'Night Cricket Bash',
        description: 'Floodlit T5 blitz — awaiting admin approval.',
        sport: 'Cricket',
        format: TournamentFormat.roundRobin,
        participationType: ParticipationType.team,
        maxParticipants: 4,
        registrationFee: 2000,
        startDate: now.add(const Duration(days: 14)),
        endDate: now.add(const Duration(days: 15)),
        registrationDeadline: now.add(const Duration(days: 12)),
        status: TournamentStatus.pendingApproval,
        prizeDetails: 'PKR 20,000',
        createdAt: now.subtract(const Duration(hours: 8)),
      ),
    ]);

    // Registrations — tour-1 (8 confirmed, one is "mine").
    final players = [
      'Ali Raza', 'Hamza Sheikh', 'Usman Khalid', 'Sara Malik',
      'Bilal Ahmed', 'Ayesha Tariq', 'Omar Farooq', 'You',
    ];
    for (var i = 0; i < players.length; i++) {
      registrations.add(RegistrationModel(
        id: 'reg-t1-$i',
        tournamentId: 'tour-1',
        playerName: players[i],
        paymentStatus: 'verified',
        status: 'confirmed',
        isMine: players[i] == 'You',
        registeredAt: now.subtract(Duration(days: 8, hours: i)),
      ));
    }
    // tour-2 — 4 teams, one payment pending verification.
    final teams = ['Thunder FC', 'City Strikers', 'Falcons', 'Real Gulberg'];
    for (var i = 0; i < teams.length; i++) {
      registrations.add(RegistrationModel(
        id: 'reg-t2-$i',
        tournamentId: 'tour-2',
        type: ParticipationType.team,
        playerName: teams[i],
        members: ['Player 1', 'Player 2', 'Player 3', 'Player 4', 'Player 5'],
        paymentStatus: 'free',
        status: i == 3 ? 'pending' : 'confirmed',
        registeredAt: now.subtract(Duration(days: 3, hours: i * 5)),
      ));
    }

    // Ongoing elimination bracket for tour-1 with quarter-finals done.
    generateBracket('tour-1');
    final rounds = brackets['tour-1']!;
    for (var m = 0; m < rounds[0].matches.length; m++) {
      enterScore('tour-1', 0, m, 6, m.isEven ? 3 : 4);
    }
  }
}
