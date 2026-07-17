import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/auth_controller.dart';
import '../data/models/booking_model.dart';
import '../data/models/chat_model.dart';
import '../services/chat_service.dart';

class ChatController extends GetxController {
  static ChatController get to => Get.find();

  final _service = ChatService();
  final _picker = ImagePicker();

  String get myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get myRole =>
      Get.isRegistered<AuthController>()
          ? AuthController.to.currentUser.value?.role.name ?? 'customer'
          : 'customer';

  final RxList<ChatModel> chats = <ChatModel>[].obs;

  StreamSubscription? _chatsSub;
  final Map<String, StreamSubscription> _msgSubs = {};
  final Map<String, RxList<MessageModel>> _msgRx = {};

  StreamSubscription? _authSub;

  @override
  void onInit() {
    super.onInit();
    _authSub = FirebaseAuth.instance
        .authStateChanges()
        .listen((_) => _listenChats());
    if (myUid.isNotEmpty) _listenChats();
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _chatsSub?.cancel();
    for (final sub in _msgSubs.values) {
      sub.cancel();
    }
    super.onClose();
  }

  void _listenChats() {
    _chatsSub?.cancel();
    if (myUid.isEmpty) {
      chats.clear();
      return;
    }
    _chatsSub = _service.userChats(myUid).listen((maps) {
      chats.assignAll(maps.map((m) {
        final count = (m['unreadCounts'] is Map)
            ? ((m['unreadCounts'] as Map)[myUid] ?? 0) as int
            : 0;
        return ChatModel.fromMap({...m, '_myUid': myUid})
            .copyWith(unreadCount: count);
      }).toList());
    }, onError: (e) => debugPrint('userChats stream error: $e'));
  }

  // ── Messages stream per chat ─────────────────────────────────────────

  RxList<MessageModel> messagesFor(String chatId) {
    if (!_msgRx.containsKey(chatId)) {
      _msgRx[chatId] = <MessageModel>[].obs;
      _msgSubs[chatId] =
          _service.messages(chatId).listen(
                (msgs) => _msgRx[chatId]!.assignAll(msgs),
                onError: (e) => debugPrint('messages stream error: $e'),
              );
    }
    return _msgRx[chatId]!;
  }

  // ── Queries ──────────────────────────────────────────────────────────

  List<ChatModel> get bookingChats =>
      chats.where((c) => c.type == ChatType.booking).toList()
        ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

  List<ChatModel> get supportChats =>
      chats.where((c) => c.type != ChatType.booking).toList()
        ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

  int get totalUnread => chats.fold(0, (s, c) => s + c.unreadCount);

  ChatModel? byId(String id) => chats.firstWhereOrNull((c) => c.id == id);

  // ── Actions ──────────────────────────────────────────────────────────

  Future<void> openChat(String id) async {
    final i = chats.indexWhere((c) => c.id == id);
    if (i != -1) {
      chats[i] = chats[i].copyWith(unreadCount: 0);
    }
    await _service.markRead(id, myUid);
  }

  Future<void> sendMessage(String chatId, String text,
      {MessageType type = MessageType.text, String? fileName}) async {
    final chat = byId(chatId);
    if (chat == null) return;

    if (type == MessageType.text) {
      if (text.trim().isEmpty) return;
      await _service.sendText(
        chatId: chatId,
        senderId: myUid,
        senderRole: myRole,
        text: text.trim(),
        participants: chat.participants,
      );
    } else if (type == MessageType.image) {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (picked == null) return;
      await _service.sendImage(
        chatId: chatId,
        senderId: myUid,
        senderRole: myRole,
        file: File(picked.path),
        participants: chat.participants,
      );
    }
  }

  // ── Support chat creation ─────────────────────────────────────────────

  Future<String> getOrCreateSupportChat() async {
    final user = Get.isRegistered<AuthController>()
        ? AuthController.to.currentUser.value
        : null;
    return _service.getOrCreateSupportChat(
      uid: myUid,
      role: myRole,
      displayName: user?.name ?? 'User',
    );
  }

  Future<String> getOrCreateBookingChat({
    required String bookingId,
    required String customerId,
    required String ownerId,
    required String title,
    required String subtitle,
  }) =>
      _service.getOrCreateBookingChat(
        bookingId: bookingId,
        customerId: customerId,
        ownerId: ownerId,
        title: title,
        subtitle: subtitle,
        requesterUid: myUid,
      );

  // ── Booking chat helpers ─────────────────────────────────────────────

  String _bookingDetails(BookingModel b) {
    final d = b.date;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return '📋 Booking Details\n'
        '━━━━━━━━━━━━━━━\n'
        '🏟 Arena: ${b.arenaName}\n'
        '🎾 Court: ${b.courtName}\n'
        '📅 Date: $dateStr\n'
        '⏰ Time: ${b.timeRange} (${b.totalHours}h)\n'
        '💰 Total: Rs ${b.totalAmount.toStringAsFixed(0)}\n'
        '💵 Deposit: Rs ${b.depositAmount.toStringAsFixed(0)}\n'
        '📌 Status: ${b.status.label}';
  }

  /// Opens (creating if needed) the chat for a booking and returns its id.
  /// When the customer starts a brand-new chat, the booking details are
  /// auto-sent as the first message so the owner has context.
  Future<String> openBookingChat(BookingModel b) async {
    final chatId = await _service.getOrCreateBookingChat(
      bookingId: b.id,
      customerId: b.customerId,
      ownerId: b.ownerId,
      title: b.arenaName,
      subtitle: '${b.courtName} · ${b.timeRange}',
      requesterUid: myUid,
    );
    final chat = byId(chatId);
    final isNew = chat == null || chat.lastMessage.isEmpty;
    if (isNew && myRole == 'customer') {
      await _service.sendText(
        chatId: chatId,
        senderId: myUid,
        senderRole: 'customer',
        text: _bookingDetails(b),
        participants: [b.customerId, b.ownerId],
      );
    }
    return chatId;
  }

  /// Sent by the owner when a booking is approved.
  Future<void> sendBookingConfirmedMessage(BookingModel b) async {
    final chatId = await _service.getOrCreateBookingChat(
      bookingId: b.id,
      customerId: b.customerId,
      ownerId: b.ownerId,
      title: b.arenaName,
      subtitle: '${b.courtName} · ${b.timeRange}',
      requesterUid: myUid,
    );
    await _service.sendText(
      chatId: chatId,
      senderId: myUid,
      senderRole: 'owner',
      text: '✅ Your booking is confirmed! Check the details below.\n\n'
          '${_bookingDetails(b.copyWith(status: BookingStatus.confirmed))}\n\n'
          'Remaining Rs ${b.remainingAmount.toStringAsFixed(0)} is payable at the arena. See you there! 🎉',
      participants: [b.customerId, b.ownerId],
    );
  }
}
