import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../data/models/ticket_model.dart';
import '../services/ticket_service.dart';

class TicketController extends GetxController {
  static TicketController get to => Get.find();

  final _service = TicketService();
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  final RxList<TicketModel> tickets = <TicketModel>[].obs;
  final Rx<TicketStatus?> filter = Rx<TicketStatus?>(null);

  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    _listen();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void _listen() {
    // Admin/staff get all tickets; others get their own.
    _sub = _service.allTickets().listen((list) => tickets.assignAll(list));
  }

  // ── Queries ──────────────────────────────────────────────────────────

  List<TicketModel> get filtered {
    final f = filter.value;
    final list =
        f == null ? tickets.toList() : tickets.where((t) => t.status == f).toList();
    return list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int get openCount =>
      tickets.where((t) => t.status == TicketStatus.open).length;

  TicketModel? byId(String id) =>
      tickets.firstWhereOrNull((t) => t.id == id);

  // ── Actions ──────────────────────────────────────────────────────────

  Future<void> setStatus(String id, TicketStatus status) =>
      _service.updateStatus(id, status);

  Future<void> assign(String id, String staffName) =>
      _service.assign(id, staffName);

  Future<void> reply(String id, String message, {String senderName = 'Admin', String role = 'admin'}) async {
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
  }

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
}
