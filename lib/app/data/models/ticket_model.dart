import 'package:cloud_firestore/cloud_firestore.dart';

// ── Enums ──────────────────────────────────────────────────────────────────

enum TicketStatus { open, inProgress, waitingForCustomer, resolved, closed }

extension TicketStatusX on TicketStatus {
  String get key {
    switch (this) {
      case TicketStatus.open:
        return 'open';
      case TicketStatus.inProgress:
        return 'in_progress';
      case TicketStatus.waitingForCustomer:
        return 'waiting_for_customer';
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
      case TicketStatus.waitingForCustomer:
        return 'Waiting for Customer';
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

enum TicketPriority { low, medium, high, urgent }

extension TicketPriorityX on TicketPriority {
  String get key => name;
  String get label {
    switch (this) {
      case TicketPriority.low:
        return 'Low';
      case TicketPriority.medium:
        return 'Medium';
      case TicketPriority.high:
        return 'High';
      case TicketPriority.urgent:
        return 'Urgent';
    }
  }

  static TicketPriority fromKey(String? key) =>
      TicketPriority.values.firstWhere(
        (p) => p.name == key,
        orElse: () => TicketPriority.medium,
      );
}

// ── Support ticket categories ──────────────────────────────────────────────

const List<String> kTicketCategories = [
  'Booking',
  'Payment',
  'Refund',
  'Arena',
  'Technical Issue',
  'Account',
  'Other',
];

// ── Status history entry ───────────────────────────────────────────────────

class StatusChange {
  final String status;
  final String changedBy;
  final String changedByRole;
  final DateTime changedAt;

  const StatusChange({
    required this.status,
    required this.changedBy,
    required this.changedByRole,
    required this.changedAt,
  });

  factory StatusChange.fromMap(Map<String, dynamic> m) => StatusChange(
        status: m['status'] ?? 'open',
        changedBy: m['changedBy'] ?? '',
        changedByRole: m['changedByRole'] ?? '',
        changedAt: (m['changedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'status': status,
        'changedBy': changedBy,
        'changedByRole': changedByRole,
        'changedAt': Timestamp.fromDate(changedAt),
      };
}

// ── Booking snapshot stored on ticket ─────────────────────────────────────

class TicketBookingSnapshot {
  final String bookingId;
  final String arenaName;
  final String courtName;
  final DateTime date;
  final String timeRange;
  final String status;

  const TicketBookingSnapshot({
    required this.bookingId,
    required this.arenaName,
    required this.courtName,
    required this.date,
    required this.timeRange,
    required this.status,
  });

  factory TicketBookingSnapshot.fromMap(Map<String, dynamic> m) =>
      TicketBookingSnapshot(
        bookingId: m['bookingId'] ?? '',
        arenaName: m['arenaName'] ?? '',
        courtName: m['courtName'] ?? '',
        date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        timeRange: m['timeRange'] ?? '',
        status: m['status'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'bookingId': bookingId,
        'arenaName': arenaName,
        'courtName': courtName,
        'date': Timestamp.fromDate(date),
        'timeRange': timeRange,
        'status': status,
      };
}

// ── Ticket message (subcollection tickets/{id}/messages) ──────────────────

enum TicketMessageType { text, image, document, system }

extension TicketMessageTypeX on TicketMessageType {
  String get key => name;
  static TicketMessageType fromKey(String? s) =>
      TicketMessageType.values.firstWhere(
        (t) => t.name == s,
        orElse: () => TicketMessageType.text,
      );
}

class TicketMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final TicketMessageType type;
  final String content;
  final String? fileName;
  final bool isReadByAdmin;
  final bool isReadByCustomer;
  final DateTime createdAt;
  final bool? failed;

  const TicketMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    this.type = TicketMessageType.text,
    required this.content,
    this.fileName,
    this.isReadByAdmin = false,
    this.isReadByCustomer = false,
    required this.createdAt,
    this.failed,
  });

  factory TicketMessage.fromMap(Map<String, dynamic> m, String docId) =>
      TicketMessage(
        id: docId,
        senderId: m['senderId'] ?? '',
        senderName: m['senderName'] ?? '',
        senderRole: m['senderRole'] ?? '',
        type: TicketMessageTypeX.fromKey(m['type']),
        content: m['content'] ?? '',
        fileName: m['fileName'],
        isReadByAdmin: m['isReadByAdmin'] ?? false,
        isReadByCustomer: m['isReadByCustomer'] ?? false,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'type': type.key,
        'content': content,
        if (fileName != null) 'fileName': fileName,
        'isReadByAdmin': isReadByAdmin,
        'isReadByCustomer': isReadByCustomer,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

// ── Ticket model ───────────────────────────────────────────────────────────

class TicketModel {
  final String id;
  final String ticketNumber;
  final String subject;
  final String description;
  final String raisedByUid;
  final String raisedByName;
  final String raisedByRole;
  final String category;
  final TicketStatus status;
  final TicketPriority priority;
  final String? bookingId;
  final String? arenaName;
  final TicketBookingSnapshot? bookingSnapshot;
  final String? assignedTo;
  final String? assignedToUid;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int unreadCountAdmin;
  final int unreadCountCustomer;
  final List<StatusChange> statusHistory;

  // Legacy — replies stored on document (kept for backward compat with old tickets)
  final List<TicketReply> replies;

  const TicketModel({
    required this.id,
    this.ticketNumber = '',
    required this.subject,
    this.description = '',
    this.raisedByUid = '',
    required this.raisedByName,
    this.raisedByRole = 'customer',
    this.category = 'Other',
    this.status = TicketStatus.open,
    this.priority = TicketPriority.medium,
    this.bookingId,
    this.arenaName,
    this.bookingSnapshot,
    this.assignedTo,
    this.assignedToUid,
    required this.createdAt,
    DateTime? updatedAt,
    this.unreadCountAdmin = 0,
    this.unreadCountCustomer = 0,
    this.statusHistory = const [],
    this.replies = const [],
  }) : updatedAt = updatedAt ?? createdAt;

  factory TicketModel.fromMap(Map<String, dynamic> m) => TicketModel(
        id: m['id'] ?? '',
        ticketNumber: m['ticketNumber'] ?? '',
        subject: m['subject'] ?? '',
        description: m['description'] ?? '',
        raisedByUid: m['raisedByUid'] ?? '',
        raisedByName: m['raisedByName'] ?? '',
        raisedByRole: m['raisedByRole'] ?? 'customer',
        category: m['category'] ?? 'Other',
        status: TicketStatusX.fromKey(m['status']),
        priority: TicketPriorityX.fromKey(m['priority']),
        bookingId: m['bookingId'],
        arenaName: m['arenaName'],
        bookingSnapshot: m['bookingSnapshot'] != null
            ? TicketBookingSnapshot.fromMap(
                Map<String, dynamic>.from(m['bookingSnapshot'] as Map))
            : null,
        assignedTo: m['assignedTo'],
        assignedToUid: m['assignedToUid'],
        createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        unreadCountAdmin: (m['unreadCountAdmin'] as num?)?.toInt() ?? 0,
        unreadCountCustomer: (m['unreadCountCustomer'] as num?)?.toInt() ?? 0,
        statusHistory: (m['statusHistory'] as List<dynamic>? ?? [])
            .map((s) => StatusChange.fromMap(Map<String, dynamic>.from(s)))
            .toList(),
        replies: (m['replies'] as List<dynamic>? ?? [])
            .map((r) => TicketReply.fromMap(Map<String, dynamic>.from(r)))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'ticketNumber': ticketNumber,
        'subject': subject,
        'description': description,
        'raisedByUid': raisedByUid,
        'raisedByName': raisedByName,
        'raisedByRole': raisedByRole,
        'category': category,
        'status': status.key,
        'priority': priority.key,
        if (bookingId != null) 'bookingId': bookingId,
        if (arenaName != null) 'arenaName': arenaName,
        if (bookingSnapshot != null) 'bookingSnapshot': bookingSnapshot!.toMap(),
        if (assignedTo != null) 'assignedTo': assignedTo,
        if (assignedToUid != null) 'assignedToUid': assignedToUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCountAdmin': unreadCountAdmin,
        'unreadCountCustomer': unreadCountCustomer,
        'statusHistory': statusHistory.map((s) => s.toMap()).toList(),
        'replies': replies.map((r) => r.toMap()).toList(),
      };

  TicketModel copyWith({
    TicketStatus? status,
    TicketPriority? priority,
    String? assignedTo,
    String? assignedToUid,
    List<TicketReply>? replies,
    List<StatusChange>? statusHistory,
    int? unreadCountAdmin,
    int? unreadCountCustomer,
    DateTime? updatedAt,
  }) =>
      TicketModel(
        id: id,
        ticketNumber: ticketNumber,
        subject: subject,
        description: description,
        raisedByUid: raisedByUid,
        raisedByName: raisedByName,
        raisedByRole: raisedByRole,
        category: category,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        bookingId: bookingId,
        arenaName: arenaName,
        bookingSnapshot: bookingSnapshot,
        assignedTo: assignedTo ?? this.assignedTo,
        assignedToUid: assignedToUid ?? this.assignedToUid,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        unreadCountAdmin: unreadCountAdmin ?? this.unreadCountAdmin,
        unreadCountCustomer: unreadCountCustomer ?? this.unreadCountCustomer,
        statusHistory: statusHistory ?? this.statusHistory,
        replies: replies ?? this.replies,
      );
}

// ── Legacy reply (kept for backward compat) ────────────────────────────────

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
