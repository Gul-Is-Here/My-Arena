import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String bookingId;
  final String arenaId;
  final String customerId;
  final String customerName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.bookingId,
    required this.arenaId,
    required this.customerId,
    this.customerName = '',
    required this.rating,
    this.comment = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'bookingId': bookingId,
        'arenaId': arenaId,
        'customerId': customerId,
        'customerName': customerName,
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory ReviewModel.fromMap(Map<String, dynamic> m) => ReviewModel(
        id: m['id'] ?? '',
        bookingId: m['bookingId'] ?? '',
        arenaId: m['arenaId'] ?? '',
        customerId: m['customerId'] ?? '',
        customerName: m['customerName'] ?? '',
        rating: (m['rating'] ?? 0).toDouble(),
        comment: m['comment'] ?? '',
        createdAt: m['createdAt'] is Timestamp
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
}
