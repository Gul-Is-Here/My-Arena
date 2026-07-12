/// Mirrors Firestore boostRequests/{requestId} from scope.md.
enum BoostType { boost, event }

enum BoostDuration { oneWeek, twoWeeks, oneMonth }

extension BoostDurationX on BoostDuration {
  String get label {
    switch (this) {
      case BoostDuration.oneWeek:
        return '1 Week';
      case BoostDuration.twoWeeks:
        return '2 Weeks';
      case BoostDuration.oneMonth:
        return '1 Month';
    }
  }

  /// Dummy pricing until settings/boostPricing is wired to Firestore.
  double get price {
    switch (this) {
      case BoostDuration.oneWeek:
        return 1500;
      case BoostDuration.twoWeeks:
        return 2500;
      case BoostDuration.oneMonth:
        return 4000;
    }
  }
}

class BoostRequestModel {
  final String id;
  final String arenaId;
  final String arenaName;
  final String ownerId;
  final BoostType type;
  final BoostDuration duration;
  final double price;
  final String paymentScreenshot;
  final String accountUsed;
  final String status; // pending | approved | rejected
  final Map<String, dynamic>? eventDetails;
  final DateTime createdAt;

  const BoostRequestModel({
    required this.id,
    required this.arenaId,
    this.arenaName = '',
    this.ownerId = '',
    this.type = BoostType.boost,
    required this.duration,
    required this.price,
    this.paymentScreenshot = '',
    this.accountUsed = '',
    this.status = 'pending',
    this.eventDetails,
    required this.createdAt,
  });

  BoostRequestModel copyWith({String? status}) => BoostRequestModel(
        id: id,
        arenaId: arenaId,
        arenaName: arenaName,
        ownerId: ownerId,
        type: type,
        duration: duration,
        price: price,
        paymentScreenshot: paymentScreenshot,
        accountUsed: accountUsed,
        status: status ?? this.status,
        eventDetails: eventDetails,
        createdAt: createdAt,
      );
}
