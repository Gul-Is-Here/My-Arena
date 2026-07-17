import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../data/models/chat_model.dart';
import '../services/chat_service.dart';

/// Admin-side view of every conversation on the platform.
class MonitoredChat {
  final ChatModel chat;
  final String partyA;
  final String partyB;
  final String pair;

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

class AdminChatController extends GetxController {
  static AdminChatController get to => Get.find();

  final _service = ChatService();

  final RxList<MonitoredChat> conversations = <MonitoredChat>[].obs;
  final RxString query = ''.obs;
  final RxString pairFilter = 'all'.obs;

  StreamSubscription? _sub;
  final Map<String, StreamSubscription> _msgSubs = {};
  final Map<String, RxList<MessageModel>> _msgRx = {};

  String get myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void onInit() {
    super.onInit();
    _listen();
  }

  @override
  void onClose() {
    _sub?.cancel();
    for (final s in _msgSubs.values) {
      s.cancel();
    }
    super.onClose();
  }

  /// Live message stream for one chat (admin can read any chat per rules).
  RxList<MessageModel> messagesFor(String chatId) {
    if (!_msgRx.containsKey(chatId)) {
      _msgRx[chatId] = <MessageModel>[].obs;
      _msgSubs[chatId] = _service
          .messages(chatId)
          .listen((msgs) => _msgRx[chatId]!.assignAll(msgs));
    }
    return _msgRx[chatId]!;
  }

  /// Admin replies in a conversation — joins as participant first so the
  /// other side's unread counts and streams include the admin.
  Future<void> sendReply(String chatId, String text) async {
    if (text.trim().isEmpty) return;
    final m = byId(chatId);
    final participants =
        List<String>.from(m?.chat.participants ?? const <String>[]);
    if (!participants.contains(myUid)) {
      await _service.addParticipant(chatId, myUid);
      participants.add(myUid);
    }
    await _service.sendText(
      chatId: chatId,
      senderId: myUid,
      senderRole: 'admin',
      text: text.trim(),
      participants: participants,
    );
  }

  void _listen() {
    _sub = _service.allChats().listen((maps) {
      conversations.assignAll(maps.map((m) {
        final chat = ChatModel.fromMap(m);
        final typeStr = m['type'] ?? 'booking';
        final String pair;
        if (typeStr == 'booking') {
          pair = 'customer_owner';
        } else if (typeStr == 'owner_support') {
          pair = 'customer_staff';
        } else {
          pair = 'customer_admin';
        }
        final parts = List<String>.from(m['participants'] ?? []);
        return MonitoredChat(
          chat: chat,
          partyA: parts.isNotEmpty ? parts[0] : '',
          partyB: parts.length > 1 ? parts[1] : 'Support',
          pair: pair,
        );
      }).toList());
    });
  }

  List<MonitoredChat> get filtered {
    final q = query.value.toLowerCase().trim();
    return conversations.where((m) {
      if (pairFilter.value != 'all' && m.pair != pairFilter.value) return false;
      if (q.isEmpty) return true;
      return m.chat.title.toLowerCase().contains(q) ||
          m.chat.subtitle.toLowerCase().contains(q) ||
          (m.chat.bookingId ?? '').toLowerCase().contains(q);
    }).toList();
  }

  MonitoredChat? byId(String id) =>
      conversations.firstWhereOrNull((m) => m.chat.id == id);

  /// Admin joins a support chat to be able to respond.
  Future<void> joinChat(String chatId, String adminUid) =>
      _service.addParticipant(chatId, adminUid);
}
