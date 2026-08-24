import 'package:cloud_firestore/cloud_firestore.dart';

/// One in-app inbox notification (mirrors every push the backend sends).
class NotificationModel {
  final String id;
  final String uid;
  final String title;
  final String body;
  final String type; // booking | review | boost | waitlist | tournament | general
  final String? relatedId;
  final bool read;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.uid,
    required this.title,
    required this.body,
    this.type = 'general',
    this.relatedId,
    this.read = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> m) =>
      NotificationModel(
        id: m['id'] ?? '',
        uid: m['uid'] ?? '',
        title: m['title'] ?? '',
        body: m['body'] ?? '',
        type: m['type'] ?? 'general',
        relatedId: m['relatedId'],
        read: m['read'] ?? false,
        createdAt: m['createdAt'] != null
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'title': title,
        'body': body,
        'type': type,
        if (relatedId != null) 'relatedId': relatedId,
        'read': read,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
