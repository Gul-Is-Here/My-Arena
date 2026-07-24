import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/auth_controller.dart';
import '../data/models/booking_model.dart';
import '../data/models/chat_model.dart';
import '../services/booking_service.dart';
import '../services/chat_service.dart';

class ChatController extends GetxController {
  static ChatController get to => Get.find();

  final _service = ChatService();
  final _bookingService = BookingService();
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

  // Live bookings per pair chat, keyed by pairKey.
  final Map<String, StreamSubscription> _pairSubs = {};
  final Map<String, RxList<BookingModel>> _pairRx = {};

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
    for (final sub in _pairSubs.values) {
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

  // ── Pair booking context ─────────────────────────────────────────────

  /// Live bookings between the chat's customer and arena. Empty list until
  /// the first snapshot arrives (or for legacy chats without a pairKey).
  RxList<BookingModel> bookingsForPair(ChatModel chat) {
    final key = chat.pairKey;
    if (key == null || chat.arenaId == null || chat.customerId == null) {
      return RxList<BookingModel>();
    }
    if (!_pairRx.containsKey(key)) {
      _pairRx[key] = <BookingModel>[].obs;
      _pairSubs[key] = _bookingService
          .pairBookings(chat.arenaId!, chat.customerId!)
          .listen(
            (list) => _pairRx[key]!.assignAll(list),
            onError: (e) => debugPrint('pairBookings stream error: $e'),
          );
    }
    return _pairRx[key]!;
  }

  /// The booking the banner should pin: the explicitly selected one if it
  /// still exists, otherwise the most actionable — awaiting deposit/approval
  /// first, then nearest upcoming confirmed, then most recent.
  BookingModel? pinnedBookingFor(ChatModel chat, List<BookingModel> bookings) {
    if (bookings.isEmpty) return null;
    if (chat.activeBookingId != null) {
      final active =
          bookings.firstWhereOrNull((b) => b.id == chat.activeBookingId);
      if (active != null) return active;
    }
    final pending = bookings
        .where((b) =>
            b.status == BookingStatus.pendingDeposit ||
            b.status == BookingStatus.depositSubmitted)
        .toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    if (pending.isNotEmpty) return pending.first;

    final upcoming = bookings
        .where((b) => b.status == BookingStatus.confirmed && b.isUpcoming)
        .toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    if (upcoming.isNotEmpty) return upcoming.first;

    final all = bookings.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.first;
  }

  static const _refMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _refWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String dateLabelFor(DateTime d) =>
      '${_refWeekdays[d.weekday - 1]} ${d.day} ${_refMonths[d.month - 1]}';

  /// Context tag stamped on outgoing messages in a pair chat.
  Map<String, dynamic>? _bookingRefFor(ChatModel chat) {
    if (chat.type != ChatType.booking || chat.pairKey == null) return null;
    final pinned = pinnedBookingFor(chat, _pairRx[chat.pairKey!] ?? []);
    if (pinned == null) return null;
    return BookingRef(
      bookingId: pinned.id,
      courtName: pinned.courtName,
      dateLabel: dateLabelFor(pinned.date),
      timeRange: pinned.timeRange,
    ).toMap();
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
    // Legacy per-booking chats gain pairKey/arenaId/customerId on first
    // open — without this the live booking banner (and the owner's
    // approve/reject actions) never appears in pre-migration chats.
    _service
        .upgradeLegacyChat(id)
        .catchError((e) => debugPrint('legacy chat upgrade failed: $e'));
    await _service.markRead(id, myUid);
  }

  /// Entry point from Arena Details: the customer's single conversation
  /// with this arena's owner, independent of any booking.
  Future<String> openArenaChat({
    required String arenaId,
    required String arenaName,
    required String ownerId,
  }) =>
      _service.getOrCreateArenaChat(
        arenaId: arenaId,
        customerId: myUid,
        ownerId: ownerId,
        title: arenaName,
        requesterUid: myUid,
      );

  Future<void> sendMessage(String chatId, String text,
      {MessageType type = MessageType.text, String? fileName}) async {
    final chat = byId(chatId);
    if (chat == null) return;

    final bookingRef = _bookingRefFor(chat);

    if (type == MessageType.text) {
      if (text.trim().isEmpty) return;
      await _service.sendText(
        chatId: chatId,
        senderId: myUid,
        senderRole: myRole,
        text: text.trim(),
        participants: chat.participants,
        bookingRef: bookingRef,
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
        bookingRef: bookingRef,
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

  /// Opens (creating if needed) the pair chat for a booking's customer–arena
  /// pair and returns its id. Legacy per-booking chats are upgraded in place
  /// by the service.
  Future<String> openBookingChat(BookingModel b) async {
    return _service.getOrCreateBookingChat(
      bookingId: b.id,
      arenaId: b.arenaId,
      customerId: b.customerId,
      ownerId: b.ownerId,
      title: b.arenaName,
      subtitle: '${b.courtName} · ${b.timeRange}',
      requesterUid: myUid,
      bookingSnapshot: BookingSnapshot(
        arenaName: b.arenaName,
        courtName: b.courtName,
        date: b.date,
        timeRange: b.timeRange,
        totalAmount: b.totalAmount,
        depositAmount: b.depositAmount,
        status: b.status.key,
      ),
    );
  }

  /// Pins a booking as the chat's shared active context.
  Future<void> setActiveBooking(String chatId, String bookingId) async {
    final i = chats.indexWhere((c) => c.id == chatId);
    if (i != -1) {
      chats[i] = chats[i].copyWith(activeBookingId: bookingId);
    }
    await _service.setActiveBooking(chatId, bookingId);
  }

  /// Sent by the owner when a booking is approved.
  Future<void> sendBookingConfirmedMessage(BookingModel b) async {
    final chatId = await _service.getOrCreateBookingChat(
      bookingId: b.id,
      arenaId: b.arenaId,
      customerId: b.customerId,
      ownerId: b.ownerId,
      title: b.arenaName,
      subtitle: '${b.courtName} · ${b.timeRange}',
      requesterUid: myUid,
      bookingSnapshot: BookingSnapshot(
        arenaName: b.arenaName,
        courtName: b.courtName,
        date: b.date,
        timeRange: b.timeRange,
        totalAmount: b.totalAmount,
        depositAmount: b.depositAmount,
        status: BookingStatus.confirmed.key,
      ),
    );
    await _service.sendText(
      chatId: chatId,
      senderId: myUid,
      senderRole: 'owner',
      text: '✅ Your booking is confirmed! '
          'Remaining Rs ${b.remainingAmount.toStringAsFixed(0)} is payable at the arena. See you there! 🎉',
      participants: [b.customerId, b.ownerId],
    );
  }
}
