import 'package:get/get.dart';

import '../data/models/chat_model.dart';

/// In-memory chat store for the UI-first phase. Real-time Firestore
/// streams replace this in the backend phase.
class ChatController extends GetxController {
  static ChatController get to => Get.find();

  final RxList<ChatModel> chats = <ChatModel>[].obs;

  /// 'me' in the dummy phase — role of the person using the app.
  final RxString myRole = 'customer'.obs;

  List<ChatModel> get bookingChats =>
      chats.where((c) => c.type == ChatType.booking).toList()
        ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

  List<ChatModel> get supportChats =>
      chats.where((c) => c.type != ChatType.booking).toList()
        ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

  int get totalUnread => chats.fold(0, (sum, c) => sum + c.unreadCount);

  ChatModel? byId(String id) => chats.firstWhereOrNull((c) => c.id == id);

  void openChat(String id) {
    final i = chats.indexWhere((c) => c.id == id);
    if (i == -1) return;
    chats[i] = chats[i].copyWith(unreadCount: 0);
  }

  void sendMessage(String chatId, String text,
      {MessageType type = MessageType.text, String? fileName}) {
    final i = chats.indexWhere((c) => c.id == chatId);
    if (i == -1 || text.trim().isEmpty && type == MessageType.text) return;
    final chat = chats[i];
    final msg = MessageModel(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'me',
      senderRole: myRole.value,
      type: type,
      content: text.trim(),
      fileName: fileName,
      isRead: false,
      createdAt: DateTime.now(),
    );
    chats[i] = chat.copyWith(
      messages: [...chat.messages, msg],
      lastMessage: type == MessageType.text
          ? msg.content
          : (type == MessageType.image ? '📷 Photo' : '📎 ${fileName ?? 'Document'}'),
      lastMessageAt: msg.createdAt,
    );
  }

  @override
  void onInit() {
    super.onInit();
    _seed();
  }

  void _seed() {
    final now = DateTime.now();
    MessageModel m(String id, String sender, String role, String text,
            Duration ago,
            {MessageType type = MessageType.text, String? fileName}) =>
        MessageModel(
          id: id,
          senderId: sender,
          senderRole: role,
          type: type,
          content: text,
          fileName: fileName,
          isRead: true,
          createdAt: now.subtract(ago),
        );

    chats.addAll([
      ChatModel(
        id: 'chat-1',
        type: ChatType.booking,
        title: 'Champions Arena',
        subtitle: 'Padel Court A · Booking #1042',
        bookingId: 'booking-seed-1',
        lastMessage: 'Perfect, see you at 6pm!',
        lastMessageAt: now.subtract(const Duration(minutes: 12)),
        unreadCount: 2,
        messages: [
          m('m1', 'me', 'customer',
              'Hi! Is the court ready for tomorrow 6pm?', const Duration(hours: 2)),
          m('m2', 'owner-1', 'owner',
              'Yes, all set. Floodlights are working too.', const Duration(hours: 1)),
          m('m3', 'me', 'customer', 'Great — can we get 4 rackets on rent?',
              const Duration(minutes: 40)),
          m('m4', 'owner-1', 'owner',
              'Sure, PKR 200 each. I\'ll keep them ready.', const Duration(minutes: 20)),
          m('m5', 'owner-1', 'owner', 'Perfect, see you at 6pm!',
              const Duration(minutes: 12)),
        ],
      ),
      ChatModel(
        id: 'chat-2',
        type: ChatType.booking,
        title: 'Padel Pro Center',
        subtitle: 'Panorama Court 1 · Booking #0987',
        bookingId: 'booking-seed-2',
        lastMessage: '📷 Photo',
        lastMessageAt: now.subtract(const Duration(days: 1)),
        messages: [
          m('m1', 'me', 'customer', 'Sending the deposit screenshot here too.',
              const Duration(days: 1, minutes: 5)),
          m('m2', 'me', 'customer', '', const Duration(days: 1),
              type: MessageType.image),
        ],
      ),
      ChatModel(
        id: 'chat-3',
        type: ChatType.customerSupport,
        title: 'MyArena Support',
        subtitle: 'Refund inquiry',
        lastMessage: 'Your refund was sent — please confirm receipt.',
        lastMessageAt: now.subtract(const Duration(hours: 5)),
        unreadCount: 1,
        messages: [
          m('m1', 'me', 'customer',
              'My booking at Smash Indoor was cancelled. Where is my refund?',
              const Duration(days: 1)),
          m('m2', 'staff-1', 'staff',
              'Hi! We\'ve checked with the owner — the refund is being processed today.',
              const Duration(hours: 20)),
          m('m3', 'staff-1', 'staff',
              'Your refund was sent — please confirm receipt.',
              const Duration(hours: 5)),
        ],
      ),
    ]);
  }
}
