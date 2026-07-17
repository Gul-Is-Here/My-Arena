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

extension BoostRequestModelX on BoostRequestModel {
  Map<String, dynamic> toMap() => {
        'arenaId': arenaId,
        'arenaName': arenaName,
        'ownerId': ownerId,
        'type': type.name,
        'duration': duration.name,
        'price': price,
        'paymentScreenshot': paymentScreenshot,
        'accountUsed': accountUsed,
        'status': status,
        if (eventDetails != null) 'eventDetails': eventDetails,
      };

  static BoostRequestModel fromMap(Map<String, dynamic> m) => BoostRequestModel(
        id: m['id'] ?? '',
        arenaId: m['arenaId'] ?? '',
        arenaName: m['arenaName'] ?? '',
        ownerId: m['ownerId'] ?? '',
        type: BoostType.values.firstWhere(
          (t) => t.name == m['type'],
          orElse: () => BoostType.boost,
        ),
        duration: BoostDuration.values.firstWhere(
          (d) => d.name == m['duration'],
          orElse: () => BoostDuration.oneWeek,
        ),
        price: (m['price'] ?? 0).toDouble(),
        paymentScreenshot: m['paymentScreenshot'] ?? '',
        accountUsed: m['accountUsed'] ?? '',
        status: m['status'] ?? 'pending',
        eventDetails: m['eventDetails'] as Map<String, dynamic>?,
        createdAt: m['createdAt'] != null
            ? (m['createdAt'] as dynamic).toDate()
            : DateTime.now(),
      );
}
