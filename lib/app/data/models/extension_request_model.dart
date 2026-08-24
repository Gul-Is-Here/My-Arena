import 'package:cloud_firestore/cloud_firestore.dart';

enum ExtensionRequestStatus { pending, approved, rejected, cancelled }

extension ExtensionRequestStatusX on ExtensionRequestStatus {
  String get key {
    switch (this) {
      case ExtensionRequestStatus.pending:
        return 'pending';
      case ExtensionRequestStatus.approved:
        return 'approved';
      case ExtensionRequestStatus.rejected:
        return 'rejected';
      case ExtensionRequestStatus.cancelled:
        return 'cancelled';
    }
  }
}

class ExtensionRequestModel {
  final String id;
  final String bookingId;
  final String customerId;
  final String customerName;
  final String ownerId;
  final String arenaId;
  final String courtId;
  final String courtName;
  /// Minutes requested: 10, 20, or 30.
  final int extensionMinutes;
  final DateTime requestedAt;
  final ExtensionRequestStatus status;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  const ExtensionRequestModel({
    required this.id,
    required this.bookingId,
    required this.customerId,
    required this.customerName,
    required this.ownerId,
    required this.arenaId,
    required this.courtId,
    required this.courtName,
    required this.extensionMinutes,
    required this.requestedAt,
    required this.status,
    this.reviewedAt,
    this.rejectionReason,
  });

  Map<String, dynamic> toMap() => {
        'bookingId': bookingId,
        'customerId': customerId,
        'customerName': customerName,
        'ownerId': ownerId,
        'arenaId': arenaId,
        'courtId': courtId,
        'courtName': courtName,
        'extensionMinutes': extensionMinutes,
        'requestedAt': Timestamp.fromDate(requestedAt),
        'status': status.key,
      };

  factory ExtensionRequestModel.fromMap(Map<String, dynamic> m, String id) =>
      ExtensionRequestModel(
        id: id,
        bookingId: m['bookingId'] ?? '',
        customerId: m['customerId'] ?? '',
        customerName: m['customerName'] ?? '',
        ownerId: m['ownerId'] ?? '',
        arenaId: m['arenaId'] ?? '',
        courtId: m['courtId'] ?? '',
        courtName: m['courtName'] ?? '',
        extensionMinutes: (m['extensionMinutes'] as int?) ?? 10,
        requestedAt: m['requestedAt'] != null
            ? (m['requestedAt'] as Timestamp).toDate()
            : DateTime.now(),
        status: ExtensionRequestStatus.values.firstWhere(
          (s) => s.key == m['status'],
          orElse: () => ExtensionRequestStatus.pending,
        ),
        reviewedAt: m['reviewedAt'] != null
            ? (m['reviewedAt'] as Timestamp).toDate()
            : null,
        rejectionReason: m['rejectionReason'] as String?,
      );
}
