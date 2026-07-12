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
}

enum TournamentFormat { elimination, roundRobin }

extension TournamentFormatX on TournamentFormat {
  String get label =>
      this == TournamentFormat.elimination ? 'Single Elimination' : 'Round Robin';
}

enum ParticipationType { individual, team }

extension ParticipationTypeX on ParticipationType {
  String get label =>
      this == ParticipationType.individual ? 'Individual' : 'Team';
}

class TournamentModel {
  final String id;
  final String createdBy;
  final String createdByRole; // 'owner' | 'admin'
  final String? arenaId;
  final String arenaName;
  final String name;
  final String description;
  final String sport;
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

  TournamentModel copyWith({
    TournamentStatus? status,
    int? registeredCount,
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
  final ParticipationType type;
  final String playerName; // individual name or team name
  final String phone;
  final List<String> members; // team members
  final String paymentStatus; // 'free' | 'pending' | 'verified'
  final String status; // 'pending' | 'confirmed' | 'rejected'
  final bool isMine; // registered by the current (dummy) user
  final DateTime registeredAt;

  const RegistrationModel({
    required this.id,
    required this.tournamentId,
    this.type = ParticipationType.individual,
    required this.playerName,
    this.phone = '',
    this.members = const [],
    this.paymentStatus = 'free',
    this.status = 'confirmed',
    this.isMine = false,
    required this.registeredAt,
  });

  RegistrationModel copyWith({String? paymentStatus, String? status}) =>
      RegistrationModel(
        id: id,
        tournamentId: tournamentId,
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
  final String status; // 'scheduled' | 'completed'

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
    if (score1 == score2) return null; // draw (round robin)
    return score1! > score2! ? participant1 : participant2;
  }

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
