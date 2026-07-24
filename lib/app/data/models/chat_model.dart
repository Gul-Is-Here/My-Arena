import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors Firestore chats/{chatId} and its messages subcollection.
enum ChatType { booking, ownerSupport, customerSupport }

/// Structured booking context stored on the chat document.
/// Written at chat creation; status field mirrored live by Cloud Function.
class BookingSnapshot {
  final String arenaName;
  final String courtName;
  final DateTime date;
  final String timeRange;
  final double totalAmount;
  final double depositAmount;
  final String status; // Firestore key: e.g. 'confirmed', 'pending_deposit'

  const BookingSnapshot({
    required this.arenaName,
    required this.courtName,
    required this.date,
    required this.timeRange,
    required this.totalAmount,
    required this.depositAmount,
    required this.status,
  });

  factory BookingSnapshot.fromMap(Map<String, dynamic> m) => BookingSnapshot(
        arenaName: m['arenaName'] ?? '',
        courtName: m['courtName'] ?? '',
        date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        timeRange: m['timeRange'] ?? '',
        totalAmount: (m['totalAmount'] as num?)?.toDouble() ?? 0,
        depositAmount: (m['depositAmount'] as num?)?.toDouble() ?? 0,
        status: m['status'] ?? 'pending_deposit',
      );

  Map<String, dynamic> toMap() => {
        'arenaName': arenaName,
        'courtName': courtName,
        'date': Timestamp.fromDate(date),
        'timeRange': timeRange,
        'totalAmount': totalAmount,
        'depositAmount': depositAmount,
        'status': status,
      };

  String get statusLabel {
    switch (status) {
      case 'pending_deposit':   return 'Pending';
      case 'deposit_submitted': return 'Submitted';
      case 'confirmed':         return 'Confirmed';
      case 'rejected':          return 'Rejected';
      case 'completed':         return 'Completed';
      case 'cancelled':         return 'Cancelled';
      case 'refund_pending':    return 'Refund Pending';
      case 'refund_sent':       return 'Refund Sent';
      case 'refund_confirmed':  return 'Refunded';
      default:                  return 'Pending';
    }
  }
}

extension ChatTypeX on ChatType {
  String get label {
    switch (this) {
      case ChatType.booking:
        return 'Booking';
      case ChatType.ownerSupport:
        return 'Owner Support';
      case ChatType.customerSupport:
        return 'Customer Support';
    }
  }
}

enum MessageType { text, image, document, system }

/// Booking context a message was sent under. Captured at send time so
/// history stays unambiguous even after the pinned booking changes.
class BookingRef {
  final String bookingId;
  final String courtName;
  final String dateLabel; // e.g. 'Mon 28 Jul'
  final String timeRange;

  const BookingRef({
    required this.bookingId,
    required this.courtName,
    required this.dateLabel,
    required this.timeRange,
  });

  factory BookingRef.fromMap(Map<String, dynamic> m) => BookingRef(
        bookingId: m['bookingId'] ?? '',
        courtName: m['courtName'] ?? '',
        dateLabel: m['dateLabel'] ?? '',
        timeRange: m['timeRange'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'bookingId': bookingId,
        'courtName': courtName,
        'dateLabel': dateLabel,
        'timeRange': timeRange,
      };

  String get label =>
      courtName.isNotEmpty ? '$courtName · $dateLabel' : dateLabel;
}

extension MessageTypeX on MessageType {
  String get key => name;
  static MessageType fromString(String? s) => MessageType.values.firstWhere(
        (t) => t.name == s,
        orElse: () => MessageType.text,
      );
}

class MessageModel {
  final String id;
  final String senderId;
  final String senderRole;
  final MessageType type;
  final String content;
  final String? fileName;
  final bool isRead;
  final DateTime createdAt;
  final BookingRef? bookingRef;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderRole,
    this.type = MessageType.text,
    required this.content,
    this.fileName,
    this.isRead = false,
    required this.createdAt,
    this.bookingRef,
  });

  factory MessageModel.fromMap(Map<String, dynamic> m) => MessageModel(
        id: m['id'] ?? '',
        senderId: m['senderId'] ?? '',
        senderRole: m['senderRole'] ?? '',
        type: MessageTypeX.fromString(m['type']),
        content: m['content'] ?? '',
        fileName: m['fileName'],
        isRead: m['isRead'] ?? false,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        bookingRef: m['bookingRef'] != null
            ? BookingRef.fromMap(
                Map<String, dynamic>.from(m['bookingRef'] as Map))
            : null,
      );

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderRole': senderRole,
        'type': type.key,
        'content': content,
        if (fileName != null) 'fileName': fileName,
        'isRead': isRead,
        'createdAt': FieldValue.serverTimestamp(),
        if (bookingRef != null) 'bookingRef': bookingRef!.toMap(),
      };
}

class ChatModel {
  final String id;
  final ChatType type;
  final String title;
  final String subtitle;
  final String? bookingId;

  /// '{arenaId}_{customerId}' — identity of a pair chat. Null on legacy
  /// per-booking chats that haven't been upgraded yet.
  final String? pairKey;
  final String? arenaId;
  final String? customerId;

  /// Last booking explicitly pinned in the context banner.
  final String? activeBookingId;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final String status;
  final List<MessageModel> messages;
  final BookingSnapshot? bookingSnapshot;

  const ChatModel({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle = '',
    this.bookingId,
    this.pairKey,
    this.arenaId,
    this.customerId,
    this.activeBookingId,
    this.participants = const [],
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.status = 'active',
    this.messages = const [],
    this.bookingSnapshot,
  });

  factory ChatModel.fromMap(Map<String, dynamic> m) {
    ChatType type;
    switch (m['type']) {
      case 'owner_support':
        type = ChatType.ownerSupport;
        break;
      case 'customer_support':
        type = ChatType.customerSupport;
        break;
      default:
        type = ChatType.booking;
    }
    return ChatModel(
      id: m['id'] ?? '',
      type: type,
      title: m['title'] ?? '',
      subtitle: m['subtitle'] ?? '',
      bookingId: m['bookingId'],
      pairKey: m['pairKey'],
      arenaId: m['arenaId'],
      customerId: m['customerId'],
      activeBookingId: m['activeBookingId'],
      participants: List<String>.from(m['participants'] ?? []),
      lastMessage: m['lastMessage'] ?? '',
      lastMessageAt: (m['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: (m['unreadCounts'] is Map)
          ? ((m['unreadCounts'] as Map)[m['_myUid']] ?? 0) as int
          : 0,
      status: m['status'] ?? 'active',
      bookingSnapshot: m['bookingSnapshot'] != null
          ? BookingSnapshot.fromMap(
              Map<String, dynamic>.from(m['bookingSnapshot'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    String typeKey;
    switch (type) {
      case ChatType.ownerSupport:
        typeKey = 'owner_support';
        break;
      case ChatType.customerSupport:
        typeKey = 'customer_support';
        break;
      default:
        typeKey = 'booking';
    }
    return {
      'type': typeKey,
      'title': title,
      'subtitle': subtitle,
      if (bookingId != null) 'bookingId': bookingId,
      if (pairKey != null) 'pairKey': pairKey,
      if (arenaId != null) 'arenaId': arenaId,
      if (customerId != null) 'customerId': customerId,
      if (activeBookingId != null) 'activeBookingId': activeBookingId,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'status': status,
      if (bookingSnapshot != null) 'bookingSnapshot': bookingSnapshot!.toMap(),
    };
  }

  ChatModel copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    String? status,
    List<MessageModel>? messages,
    BookingSnapshot? bookingSnapshot,
    String? activeBookingId,
  }) =>
      ChatModel(
        id: id,
        type: type,
        title: title,
        subtitle: subtitle,
        bookingId: bookingId,
        pairKey: pairKey,
        arenaId: arenaId,
        customerId: customerId,
        activeBookingId: activeBookingId ?? this.activeBookingId,
        participants: participants,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        unreadCount: unreadCount ?? this.unreadCount,
        status: status ?? this.status,
        messages: messages ?? this.messages,
        bookingSnapshot: bookingSnapshot ?? this.bookingSnapshot,
      );
}
