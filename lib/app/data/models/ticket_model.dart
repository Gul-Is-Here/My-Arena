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
}

class TicketReply {
  final String id;
  final String senderName;
  final String senderRole; // 'customer' | 'owner' | 'staff' | 'admin'
  final String message;
  final DateTime createdAt;

  const TicketReply({
    required this.id,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.createdAt,
  });
}

class TicketModel {
  final String id;
  final String subject;
  final String description;
  final String raisedByName;
  final String raisedByRole; // 'customer' | 'owner'
  final String category; // 'refund' | 'booking' | 'payment' | 'arena' | 'other'
  final String? bookingId;
  final String? arenaName;
  final TicketStatus status;
  final String? assignedTo; // staff name
  final DateTime createdAt;
  final List<TicketReply> replies;

  const TicketModel({
    required this.id,
    required this.subject,
    this.description = '',
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

  TicketModel copyWith({
    TicketStatus? status,
    String? assignedTo,
    List<TicketReply>? replies,
  }) =>
      TicketModel(
        id: id,
        subject: subject,
        description: description,
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
