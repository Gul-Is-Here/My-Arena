import 'package:get/get.dart';

import '../data/models/chat_model.dart';

/// A conversation between two parties, monitored by admin.
class MonitoredChat {
  final ChatModel chat;
  final String partyA; // e.g. 'Ali Raza (Customer)'
  final String partyB; // e.g. 'Usman Khalid (Owner)'
  final String pair; // 'customer_owner' | 'customer_staff' | 'customer_admin'

  const MonitoredChat({
    required this.chat,
    required this.partyA,
    required this.partyB,
    required this.pair,
  });

  String get pairLabel {
    switch (pair) {
      case 'customer_owner':
        return 'Customer ↔ Owner';
      case 'customer_staff':
        return 'Customer ↔ Staff';
      default:
        return 'Customer ↔ Admin';
    }
  }
}

/// Admin chat monitoring — every conversation on the platform.
/// Firestore collectionGroup streams replace this in the backend phase.
class AdminChatController extends GetxController {
  static AdminChatController get to => Get.find();

  final RxList<MonitoredChat> conversations = <MonitoredChat>[].obs;
  final RxString query = ''.obs;
  final RxString pairFilter = 'all'.obs; // all | customer_owner | customer_staff | customer_admin

  List<MonitoredChat> get filtered {
    final q = query.value.toLowerCase().trim();
    return conversations.where((m) {
      if (pairFilter.value != 'all' && m.pair != pairFilter.value) return false;
      if (q.isEmpty) return true;
      return m.partyA.toLowerCase().contains(q) ||
          m.partyB.toLowerCase().contains(q) ||
          m.chat.title.toLowerCase().contains(q) ||
          m.chat.subtitle.toLowerCase().contains(q) ||
          (m.chat.bookingId ?? '').toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.chat.lastMessageAt.compareTo(a.chat.lastMessageAt));
  }

  MonitoredChat? byId(String id) =>
      conversations.firstWhereOrNull((m) => m.chat.id == id);

  @override
  void onInit() {
    super.onInit();
    _seed();
  }

  void _seed() {
    final now = DateTime.now();
    MessageModel m(String id, String sender, String role, String text,
            Duration ago) =>
        MessageModel(
          id: id,
          senderId: sender,
          senderRole: role,
          type: MessageType.text,
          content: text,
          isRead: true,
          createdAt: now.subtract(ago),
        );

    conversations.assignAll([
      MonitoredChat(
        partyA: 'Ali Raza (Customer)',
        partyB: 'Usman Khalid (Owner)',
        pair: 'customer_owner',
        chat: ChatModel(
          id: 'mon-1',
          type: ChatType.booking,
          title: 'Champions Arena',
          subtitle: 'Padel Court A · Booking #1042',
          bookingId: '#1042',
          lastMessage: 'Perfect, see you at 6pm!',
          lastMessageAt: now.subtract(const Duration(minutes: 12)),
          messages: [
            m('m1', 'cust-1', 'customer',
                'Hi! Is the court ready for tomorrow 6pm?', const Duration(hours: 2)),
            m('m2', 'owner-1', 'owner',
                'Yes, all set. Floodlights are working too.', const Duration(hours: 1)),
            m('m3', 'cust-1', 'customer',
                'Great — can we get 4 rackets on rent?', const Duration(minutes: 40)),
            m('m4', 'owner-1', 'owner', 'Perfect, see you at 6pm!',
                const Duration(minutes: 12)),
          ],
        ),
      ),
      MonitoredChat(
        partyA: 'Hamza Sheikh (Customer)',
        partyB: 'Bilal Ahmed (Staff)',
        pair: 'customer_staff',
        chat: ChatModel(
          id: 'mon-2',
          type: ChatType.customerSupport,
          title: 'Refund inquiry',
          subtitle: 'Smash Indoor Sports · Booking #0987',
          bookingId: '#0987',
          lastMessage: 'Your refund was sent — please confirm receipt.',
          lastMessageAt: now.subtract(const Duration(hours: 5)),
          messages: [
            m('m1', 'cust-2', 'customer',
                'My booking was cancelled. Where is my refund?',
                const Duration(days: 1)),
            m('m2', 'staff-1', 'staff',
                'We\'ve checked with the owner — it is being processed today.',
                const Duration(hours: 20)),
            m('m3', 'staff-1', 'staff',
                'Your refund was sent — please confirm receipt.',
                const Duration(hours: 5)),
          ],
        ),
      ),
      MonitoredChat(
        partyA: 'Sara Malik (Customer)',
        partyB: 'Admin',
        pair: 'customer_admin',
        chat: ChatModel(
          id: 'mon-3',
          type: ChatType.customerSupport,
          title: 'Account ban appeal',
          subtitle: 'Account issue',
          lastMessage: 'Your appeal is under review.',
          lastMessageAt: now.subtract(const Duration(hours: 8)),
          messages: [
            m('m1', 'cust-3', 'customer',
                'Why was my account banned? I did nothing wrong.',
                const Duration(days: 1, hours: 2)),
            m('m2', 'admin', 'admin', 'Your appeal is under review.',
                const Duration(hours: 8)),
          ],
        ),
      ),
      MonitoredChat(
        partyA: 'Ahmed Nawaz (Customer)',
        partyB: 'Usman Khalid (Owner)',
        pair: 'customer_owner',
        chat: ChatModel(
          id: 'mon-4',
          type: ChatType.booking,
          title: 'Padel Pro Center',
          subtitle: 'Panorama Court 1 · Booking #1101',
          bookingId: '#1101',
          lastMessage: 'Deposit screenshot attached.',
          lastMessageAt: now.subtract(const Duration(days: 1)),
          messages: [
            m('m1', 'cust-4', 'customer', 'Deposit screenshot attached.',
                const Duration(days: 1)),
          ],
        ),
      ),
    ]);
  }
}
