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

class MessageModel {
  final String id;
  final String senderId;
  final String senderRole; // 'customer' | 'owner' | 'staff' | 'admin'
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
}

class ChatModel {
  final String id;
  final ChatType type;
  final String title; // other party / topic shown in the list
  final String subtitle; // arena or booking context
  final String? bookingId;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final String status; // 'active' | 'closed'
  final List<MessageModel> messages;

  const ChatModel({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle = '',
    this.bookingId,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.status = 'active',
    this.messages = const [],
  });

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
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        unreadCount: unreadCount ?? this.unreadCount,
        status: status ?? this.status,
        messages: messages ?? this.messages,
      );
}
