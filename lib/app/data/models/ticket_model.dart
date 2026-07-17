import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors Firestore tickets/{ticketId} — support ticket module.
enum TicketStatus { open, inProgress, resolved, closed }

extension TicketStatusX on TicketStatus {
  String get key {
    switch (this) {
      case TicketStatus.open:
        return 'open';
      case TicketStatus.inProgress:
        return 'in_progress';
      case TicketStatus.resolved:
        return 'resolved';
      case TicketStatus.closed:
        return 'closed';
    }
  }

  String get label {
    switch (this) {
      case TicketStatus.open:
        return 'Open';
      case TicketStatus.inProgress:
        return 'In Progress';
      case TicketStatus.resolved:
        return 'Resolved';
      case TicketStatus.closed:
        return 'Closed';
    }
  }

  static TicketStatus fromKey(String? key) => TicketStatus.values.firstWhere(
        (s) => s.key == key,
        orElse: () => TicketStatus.open,
      );
}

class TicketReply {
  final String id;
  final String senderName;
  final String senderRole;
  final String message;
  final DateTime createdAt;

  const TicketReply({
    required this.id,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.createdAt,
  });

  factory TicketReply.fromMap(Map<String, dynamic> m) => TicketReply(
        id: m['id'] ?? '',
        senderName: m['senderName'] ?? '',
        senderRole: m['senderRole'] ?? '',
        message: m['message'] ?? '',
        createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'senderName': senderName,
        'senderRole': senderRole,
        'message': message,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

class TicketModel {
  final String id;
  final String subject;
  final String description;
  final String raisedByUid;
  final String raisedByName;
  final String raisedByRole;
  final String category;
  final String? bookingId;
  final String? arenaName;
  final TicketStatus status;
  final String? assignedTo;
  final DateTime createdAt;
  final List<TicketReply> replies;

  const TicketModel({
    required this.id,
    required this.subject,
    this.description = '',
    this.raisedByUid = '',
    required this.raisedByName,
    this.raisedByRole = 'customer',
    this.category = 'other',
    this.bookingId,
    this.arenaName,
    this.status = TicketStatus.open,
    this.assignedTo,
    required this.createdAt,
    this.replies = const [],
  });

  factory TicketModel.fromMap(Map<String, dynamic> m) => TicketModel(
        id: m['id'] ?? '',
        subject: m['subject'] ?? '',
        description: m['description'] ?? '',
        raisedByUid: m['raisedByUid'] ?? '',
        raisedByName: m['raisedByName'] ?? '',
        raisedByRole: m['raisedByRole'] ?? 'customer',
        category: m['category'] ?? 'other',
        bookingId: m['bookingId'],
        arenaName: m['arenaName'],
        status: TicketStatusX.fromKey(m['status']),
        assignedTo: m['assignedTo'],
        createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        replies: (m['replies'] as List<dynamic>? ?? [])
            .map((r) => TicketReply.fromMap(Map<String, dynamic>.from(r)))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'subject': subject,
        'description': description,
        'raisedByUid': raisedByUid,
        'raisedByName': raisedByName,
        'raisedByRole': raisedByRole,
        'category': category,
        if (bookingId != null) 'bookingId': bookingId,
        if (arenaName != null) 'arenaName': arenaName,
        'status': status.key,
        if (assignedTo != null) 'assignedTo': assignedTo,
        'createdAt': FieldValue.serverTimestamp(),
        'replies': replies.map((r) => r.toMap()).toList(),
      };

  TicketModel copyWith({
    TicketStatus? status,
    String? assignedTo,
    List<TicketReply>? replies,
  }) =>
      TicketModel(
        id: id,
        subject: subject,
        description: description,
        raisedByUid: raisedByUid,
        raisedByName: raisedByName,
        raisedByRole: raisedByRole,
        category: category,
        bookingId: bookingId,
        arenaName: arenaName,
        status: status ?? this.status,
        assignedTo: assignedTo ?? this.assignedTo,
        createdAt: createdAt,
        replies: replies ?? this.replies,
      );
}
