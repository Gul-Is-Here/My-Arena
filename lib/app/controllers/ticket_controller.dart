import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../data/models/ticket_model.dart';
import '../services/ticket_service.dart';

/// Admin/staff controller — streams all tickets.
class TicketController extends GetxController {
  static TicketController get to => Get.find();

  final _service = TicketService();
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  final RxList<TicketModel> tickets = <TicketModel>[].obs;
  final Rx<TicketStatus?> filter = Rx<TicketStatus?>(null);
  final RxString search = ''.obs;

  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    _sub = _service.allTickets().listen((list) => tickets.assignAll(list));
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  List<TicketModel> get filtered {
    var list = filter.value == null
        ? tickets.toList()
        : tickets.where((t) => t.status == filter.value).toList();

    final q = search.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((t) =>
              t.ticketNumber.toLowerCase().contains(q) ||
              t.subject.toLowerCase().contains(q) ||
              t.raisedByName.toLowerCase().contains(q) ||
              (t.bookingId?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  int get openCount =>
      tickets.where((t) => t.status == TicketStatus.open).length;

  int get totalUnread =>
      tickets.fold(0, (sum, t) => sum + t.unreadCountAdmin);

  TicketModel? byId(String id) =>
      tickets.firstWhereOrNull((t) => t.id == id);

  Stream<List<TicketMessage>> messagesStream(String ticketId) =>
      _service.messagesStream(ticketId);

  // ── Actions ──────────────────────────────────────────────────────────

  Future<void> setStatus(String id, TicketStatus status) {
    final adminName = Get.isRegistered<AuthController>()
        ? (AuthController.to.currentUser.value?.name ?? 'Admin')
        : 'Admin';
    return _service.updateStatus(id, status,
        changedBy: adminName, changedByRole: 'admin');
  }

  Future<void> setPriority(String id, TicketPriority priority) =>
      _service.setPriority(id, priority);

  Future<void> assign(String id, String staffName, String staffUid) =>
      _service.assign(id, staffName, staffUid);

  Future<void> sendMessage(String ticketId, String content) async {
    if (content.trim().isEmpty) return;
    await _service.sendMessage(
      ticketId,
      senderId: _uid,
      senderName: 'Support Team',
      senderRole: 'admin',
      content: content.trim(),
    );
    await _service.markReadByAdmin(ticketId);
  }

  Future<void> markRead(String ticketId) =>
      _service.markReadByAdmin(ticketId);

  Future<String> createTicket({
    required String subject,
    required String description,
    required String raisedByName,
    required String raisedByRole,
    required String category,
    String? bookingId,
    String? arenaName,
  }) =>
      _service.createTicket(TicketModel(
        id: '',
        subject: subject,
        description: description,
        raisedByUid: _uid,
        raisedByName: raisedByName,
        raisedByRole: raisedByRole,
        category: category,
        bookingId: bookingId,
        arenaName: arenaName,
        createdAt: DateTime.now(),
      ));

  // Legacy reply still used by admin_ticket_detail_screen
  Future<void> reply(String id, String message,
      {String senderName = 'Admin', String role = 'admin'}) async {
    if (message.trim().isEmpty) return;
    await _service.addReply(
      id,
      TicketReply(
        id: 'r-${DateTime.now().millisecondsSinceEpoch}',
        senderName: senderName,
        senderRole: role,
        message: message.trim(),
        createdAt: DateTime.now(),
      ),
    );
    await sendMessage(id, message);
  }
}
