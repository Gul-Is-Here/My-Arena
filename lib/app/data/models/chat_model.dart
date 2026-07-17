import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors Firestore chats/{chatId} and its messages subcollection.
enum ChatType { booking, ownerSupport, customerSupport }

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

enum MessageType { text, image, document }

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

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderRole,
    this.type = MessageType.text,
    required this.content,
    this.fileName,
    this.isRead = false,
    required this.createdAt,
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
      );

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderRole': senderRole,
        'type': type.key,
        'content': content,
        if (fileName != null) 'fileName': fileName,
        'isRead': isRead,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

class ChatModel {
  final String id;
  final ChatType type;
  final String title;
  final String subtitle;
  final String? bookingId;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final String status;
  final List<MessageModel> messages;

  const ChatModel({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle = '',
    this.bookingId,
    this.participants = const [],
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.status = 'active',
    this.messages = const [],
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
      participants: List<String>.from(m['participants'] ?? []),
      lastMessage: m['lastMessage'] ?? '',
      lastMessageAt: (m['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: (m['unreadCounts'] is Map)
          ? ((m['unreadCounts'] as Map)[m['_myUid']] ?? 0) as int
          : 0,
      status: m['status'] ?? 'active',
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
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'status': status,
    };
  }

  ChatModel copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    String? status,
    List<MessageModel>? messages,
  }) =>
      ChatModel(
        id: id,
        type: type,
        title: title,
        subtitle: subtitle,
        bookingId: bookingId,
        participants: participants,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        unreadCount: unreadCount ?? this.unreadCount,
        status: status ?? this.status,
        messages: messages ?? this.messages,
      );
}
