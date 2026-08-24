import 'package:cloud_firestore/cloud_firestore.dart';

enum ProductCategory {
  equipment,
  beverages,
  food,
  coaching,
  locker,
  parking,
  merchandise,
  other,
}

extension ProductCategoryX on ProductCategory {
  String get key => name;

  String get label => switch (this) {
        ProductCategory.equipment => 'Equipment Rental',
        ProductCategory.beverages => 'Beverages',
        ProductCategory.food => 'Food & Snacks',
        ProductCategory.coaching => 'Coaching',
        ProductCategory.locker => 'Locker',
        ProductCategory.parking => 'Parking',
        ProductCategory.merchandise => 'Merchandise',
        ProductCategory.other => 'Other',
      };

  static ProductCategory fromKey(String? k) =>
      ProductCategory.values.firstWhere(
        (c) => c.name == k,
        orElse: () => ProductCategory.other,
      );
}

class PosProductModel {
  final String id;
  final String arenaId;
  final String name;
  final String description;
  final ProductCategory category;
  final double price;
  final bool isActive;
  final DateTime createdAt;

  const PosProductModel({
    required this.id,
    required this.arenaId,
    required this.name,
    this.description = '',
    required this.category,
    required this.price,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'arenaId': arenaId,
        'name': name,
        'description': description,
        'category': category.key,
        'price': price,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory PosProductModel.fromMap(Map<String, dynamic> m) => PosProductModel(
        id: m['id'] ?? '',
        arenaId: m['arenaId'] ?? '',
        name: m['name'] ?? '',
        description: m['description'] ?? '',
        category: ProductCategoryX.fromKey(m['category']),
        price: (m['price'] as num?)?.toDouble() ?? 0,
        isActive: m['isActive'] ?? true,
        createdAt: m['createdAt'] is Timestamp
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
}
