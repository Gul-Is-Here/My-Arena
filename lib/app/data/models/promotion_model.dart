import 'package:cloud_firestore/cloud_firestore.dart';

enum DiscountType { percentage, flat }

enum PromotionStatus { active, paused, expired }

/// 'arena' = owner-scoped (applies to one arena only).
/// 'platform' = Super Admin-scoped (applies across all arenas; wins over arena promos).
enum PromotionScope { arena, platform }

class PromotionModel {
  final String id;

  /// Null for platform-scoped promotions.
  final String? arenaId;

  /// UID of the creator (owner UID for arena scope; admin UID for platform scope).
  final String ownerId;

  final PromotionScope scope;
  final String title;
  final String? description;

  /// Normalized uppercase promo code (e.g. "ARENA10").
  final String code;

  final DiscountType discountType;

  /// Percentage (0–100) or flat PKR amount depending on [discountType].
  final double discountValue;

  /// Max discount in PKR when type is percentage (null = no cap).
  final double? maxDiscountAmount;

  /// Minimum booking amount in PKR required for this promo to apply (null = no minimum).
  final double? minBookingAmount;

  /// Max number of total uses (null = unlimited).
  final int? maxUses;

  /// Times this code has been successfully used.
  final int usageCount;

  /// Expiry datetime (null = no expiry).
  final DateTime? expiresAt;

  final PromotionStatus status;
  final DateTime createdAt;

  bool get isPlatform => scope == PromotionScope.platform;

  const PromotionModel({
    required this.id,
    this.arenaId,
    required this.ownerId,
    required this.scope,
    required this.title,
    this.description,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.maxDiscountAmount,
    this.minBookingAmount,
    this.maxUses,
    this.usageCount = 0,
    this.expiresAt,
    this.status = PromotionStatus.active,
    required this.createdAt,
  });

  bool get isActive => status == PromotionStatus.active &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now())) &&
      (maxUses == null || usageCount < maxUses!);

  /// Whether this promo can be applied to the given [bookingTotal].
  bool isEligibleFor(double bookingTotal) =>
      isActive && (minBookingAmount == null || bookingTotal >= minBookingAmount!);

  /// Calculates discount for [bookingTotal]. Returns the PKR amount off.
  double discountFor(double bookingTotal) {
    if (!isEligibleFor(bookingTotal)) return 0;
    if (discountType == DiscountType.flat) {
      return discountValue.clamp(0, bookingTotal);
    }
    final pct = (bookingTotal * discountValue / 100);
    return maxDiscountAmount != null ? pct.clamp(0, maxDiscountAmount!) : pct;
  }

  /// Human-readable label for booking details: "Arena Special" or "Platform Offer".
  String get sourceLabel =>
      scope == PromotionScope.platform ? 'Platform Offer' : 'Arena Special';

  /// Short discount summary, e.g. "20% OFF" or "Rs. 500 OFF".
  String get discountLabel {
    if (discountType == DiscountType.percentage) {
      return '${discountValue.toStringAsFixed(0)}% OFF';
    }
    return 'Rs. ${discountValue.toStringAsFixed(0)} OFF';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        if (arenaId != null) 'arenaId': arenaId,
        'ownerId': ownerId,
        'scope': scope.name,
        'title': title,
        if (description != null) 'description': description,
        'code': code,
        'codeNormalized': code.toUpperCase().trim(),
        'discountType': discountType.name,
        'discountValue': discountValue,
        if (maxDiscountAmount != null) 'maxDiscountAmount': maxDiscountAmount,
        if (minBookingAmount != null) 'minBookingAmount': minBookingAmount,
        if (maxUses != null) 'maxUses': maxUses,
        'usageCount': usageCount,
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory PromotionModel.fromMap(Map<String, dynamic> m) => PromotionModel(
        id: m['id'] ?? '',
        arenaId: m['arenaId'] as String?,
        ownerId: m['ownerId'] ?? '',
        scope: PromotionScope.values.firstWhere(
          (s) => s.name == m['scope'],
          orElse: () => PromotionScope.arena,
        ),
        title: m['title'] ?? '',
        description: m['description'] as String?,
        code: m['code'] ?? '',
        discountType: DiscountType.values.firstWhere(
          (t) => t.name == m['discountType'],
          orElse: () => DiscountType.percentage,
        ),
        discountValue: (m['discountValue'] as num?)?.toDouble() ?? 0,
        maxDiscountAmount: (m['maxDiscountAmount'] as num?)?.toDouble(),
        minBookingAmount: (m['minBookingAmount'] as num?)?.toDouble(),
        maxUses: m['maxUses'] as int?,
        usageCount: (m['usageCount'] as int?) ?? 0,
        expiresAt: m['expiresAt'] != null
            ? (m['expiresAt'] as Timestamp).toDate()
            : null,
        status: PromotionStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => PromotionStatus.active,
        ),
        createdAt: m['createdAt'] != null
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
}
