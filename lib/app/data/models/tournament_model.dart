import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors Firestore tournaments/{id}, registrations/{id} and
/// brackets/{id} from scope.md.
enum TournamentStatus {
  draft,
  pendingApproval,
  approved,
  registrationOpen,
  ongoing,
  completed,
  rejected,
}

extension TournamentStatusX on TournamentStatus {
  String get key {
    switch (this) {
      case TournamentStatus.draft:
        return 'draft';
      case TournamentStatus.pendingApproval:
        return 'pending_approval';
      case TournamentStatus.approved:
        return 'approved';
      case TournamentStatus.registrationOpen:
        return 'registration_open';
      case TournamentStatus.ongoing:
        return 'ongoing';
      case TournamentStatus.completed:
        return 'completed';
      case TournamentStatus.rejected:
        return 'rejected';
    }
  }

  String get label {
    switch (this) {
      case TournamentStatus.draft:
        return 'Draft';
      case TournamentStatus.pendingApproval:
        return 'Pending Approval';
      case TournamentStatus.approved:
        return 'Approved';
      case TournamentStatus.registrationOpen:
        return 'Registration Open';
      case TournamentStatus.ongoing:
        return 'Ongoing';
      case TournamentStatus.completed:
        return 'Completed';
      case TournamentStatus.rejected:
        return 'Rejected';
    }
  }

  static TournamentStatus fromKey(String? key) =>
      TournamentStatus.values.firstWhere(
        (s) => s.key == key,
        orElse: () => TournamentStatus.pendingApproval,
      );
}

enum TournamentFormat { elimination, roundRobin }

extension TournamentFormatX on TournamentFormat {
  String get key => this == TournamentFormat.elimination ? 'elimination' : 'round_robin';
  String get label =>
      this == TournamentFormat.elimination ? 'Single Elimination' : 'Round Robin';
  static TournamentFormat fromKey(String? k) =>
      k == 'round_robin' ? TournamentFormat.roundRobin : TournamentFormat.elimination;
}

enum ParticipationType { individual, team }

extension ParticipationTypeX on ParticipationType {
  String get key => name;
  String get label =>
      this == ParticipationType.individual ? 'Individual' : 'Team';
  static ParticipationType fromKey(String? k) =>
      k == 'team' ? ParticipationType.team : ParticipationType.individual;
}

class TournamentModel {
  final String id;
  final String createdBy;
  final String createdByRole;
  final String? arenaId;
  final String arenaName;
  final String name;
  final String description;
  final String sport;
  final String bannerImage;
  final TournamentFormat format;
  final ParticipationType participationType;
  final int maxParticipants;
  final int registeredCount;
  final double registrationFee;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime registrationDeadline;
  final TournamentStatus status;
  final String prizeDetails;
  final DateTime createdAt;

  const TournamentModel({
    required this.id,
    this.createdBy = '',
    this.createdByRole = 'owner',
    this.arenaId,
    this.arenaName = '',
    required this.name,
    this.description = '',
    required this.sport,
    this.bannerImage = '',
    this.format = TournamentFormat.elimination,
    this.participationType = ParticipationType.individual,
    this.maxParticipants = 8,
    this.registeredCount = 0,
    this.registrationFee = 0,
    required this.startDate,
    required this.endDate,
    required this.registrationDeadline,
    this.status = TournamentStatus.pendingApproval,
    this.prizeDetails = '',
    required this.createdAt,
  });

  bool get isFree => registrationFee <= 0;

  factory TournamentModel.fromMap(Map<String, dynamic> m) => TournamentModel(
        id: m['id'] ?? '',
        createdBy: m['createdBy'] ?? '',
        createdByRole: m['createdByRole'] ?? 'owner',
        arenaId: m['arenaId'],
        arenaName: m['arenaName'] ?? '',
        name: m['name'] ?? '',
        description: m['description'] ?? '',
        sport: m['sport'] ?? '',
        bannerImage: m['bannerImage'] ?? '',
        format: TournamentFormatX.fromKey(m['format']),
        participationType: ParticipationTypeX.fromKey(m['participationType']),
        maxParticipants: (m['maxParticipants'] ?? 8) as int,
        registeredCount: (m['registeredCount'] ?? 0) as int,
        registrationFee: (m['registrationFee'] ?? 0).toDouble(),
        startDate: (m['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        endDate: (m['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        registrationDeadline:
            (m['registrationDeadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
        status: TournamentStatusX.fromKey(m['status']),
        prizeDetails: m['prizeDetails'] ?? '',
        createdAt:
            (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'createdBy': createdBy,
        'createdByRole': createdByRole,
        if (arenaId != null) 'arenaId': arenaId,
        'arenaName': arenaName,
        'name': name,
        'description': description,
        'sport': sport,
        'bannerImage': bannerImage,
        'format': format.key,
        'participationType': participationType.key,
        'maxParticipants': maxParticipants,
        'registeredCount': registeredCount,
        'registrationFee': registrationFee,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'registrationDeadline': Timestamp.fromDate(registrationDeadline),
        'status': status.key,
        'prizeDetails': prizeDetails,
        'createdAt': FieldValue.serverTimestamp(),
      };

  TournamentModel copyWith({
    TournamentStatus? status,
    int? registeredCount,
    String? bannerImage,
  }) =>
      TournamentModel(
        id: id,
        createdBy: createdBy,
        createdByRole: createdByRole,
        arenaId: arenaId,
        arenaName: arenaName,
        name: name,
        description: description,
        sport: sport,
        bannerImage: bannerImage ?? this.bannerImage,
        format: format,
        participationType: participationType,
        maxParticipants: maxParticipants,
        registeredCount: registeredCount ?? this.registeredCount,
        registrationFee: registrationFee,
        startDate: startDate,
        endDate: endDate,
        registrationDeadline: registrationDeadline,
        status: status ?? this.status,
        prizeDetails: prizeDetails,
        createdAt: createdAt,
      );
}

class RegistrationModel {
  final String id;
  final String tournamentId;
  final String userId;
  final ParticipationType type;
  final String playerName;
  final String phone;
  final List<String> members;
  final String paymentStatus; // 'free' | 'pending' | 'verified'
  final String status; // 'pending' | 'confirmed' | 'rejected'
  final bool isMine;
  final DateTime registeredAt;

  const RegistrationModel({
    required this.id,
    required this.tournamentId,
    this.userId = '',
    this.type = ParticipationType.individual,
    required this.playerName,
    this.phone = '',
    this.members = const [],
    this.paymentStatus = 'free',
    this.status = 'confirmed',
    this.isMine = false,
    required this.registeredAt,
  });

  factory RegistrationModel.fromMap(Map<String, dynamic> m, {String myUid = ''}) =>
      RegistrationModel(
        id: m['id'] ?? '',
        tournamentId: m['tournamentId'] ?? '',
        userId: m['userId'] ?? '',
        type: ParticipationTypeX.fromKey(m['type']),
        playerName: m['playerName'] ?? '',
        phone: m['phone'] ?? '',
        members: List<String>.from(m['members'] ?? []),
        paymentStatus: m['paymentStatus'] ?? 'free',
        status: m['status'] ?? 'confirmed',
        isMine: myUid.isNotEmpty && m['userId'] == myUid,
        registeredAt:
            (m['registeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'tournamentId': tournamentId,
        'userId': userId,
        'type': type.key,
        'playerName': playerName,
        'phone': phone,
        'members': members,
        'paymentStatus': paymentStatus,
        'status': status,
        'registeredAt': FieldValue.serverTimestamp(),
      };

  RegistrationModel copyWith({String? paymentStatus, String? status}) =>
      RegistrationModel(
        id: id,
        tournamentId: tournamentId,
        userId: userId,
        type: type,
        playerName: playerName,
        phone: phone,
        members: members,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        status: status ?? this.status,
        isMine: isMine,
        registeredAt: registeredAt,
      );
}

class MatchModel {
  final String id;
  final String? participant1;
  final String? participant2;
  final int? score1;
  final int? score2;
  final String status;

  const MatchModel({
    required this.id,
    this.participant1,
    this.participant2,
    this.score1,
    this.score2,
    this.status = 'scheduled',
  });

  String? get winner {
    if (score1 == null || score2 == null) return null;
    if (score1 == score2) return null;
    return score1! > score2! ? participant1 : participant2;
  }

  factory MatchModel.fromMap(Map<String, dynamic> m) => MatchModel(
        id: m['id'] ?? '',
        participant1: m['participant1'],
        participant2: m['participant2'],
        score1: m['score1'],
        score2: m['score2'],
        status: m['status'] ?? 'scheduled',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'participant1': participant1,
        'participant2': participant2,
        'score1': score1,
        'score2': score2,
        'status': status,
      };

  MatchModel copyWith({
    String? participant1,
    String? participant2,
    int? score1,
    int? score2,
    String? status,
  }) =>
      MatchModel(
        id: id,
        participant1: participant1 ?? this.participant1,
        participant2: participant2 ?? this.participant2,
        score1: score1 ?? this.score1,
        score2: score2 ?? this.score2,
        status: status ?? this.status,
      );
}

class BracketRound {
  final int roundNumber;
  final List<MatchModel> matches;

  const BracketRound({required this.roundNumber, required this.matches});

  factory BracketRound.fromMap(Map<String, dynamic> m) => BracketRound(
        roundNumber: (m['roundNumber'] ?? 1) as int,
        matches: (m['matches'] as List<dynamic>? ?? [])
            .map((x) => MatchModel.fromMap(Map<String, dynamic>.from(x)))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'roundNumber': roundNumber,
        'matches': matches.map((m) => m.toMap()).toList(),
      };
}

/// Round-robin points table row.
class LeaderboardEntry {
  final String name;
  final int played;
  final int won;
  final int lost;
  final int drawn;
  final int points;

  const LeaderboardEntry({
    required this.name,
    this.played = 0,
    this.won = 0,
    this.lost = 0,
    this.drawn = 0,
    this.points = 0,
  });
}
