import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../data/models/booking_model.dart';
import '../data/models/ticket_model.dart';
import '../services/booking_service.dart';
import '../services/ticket_service.dart';

/// Customer-facing ticket controller.
class CustomerTicketController extends GetxController {
  static CustomerTicketController get to => Get.find();

  final _service = TicketService();
  final _bookingService = BookingService();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _userName =>
      AuthController.to.currentUser.value?.name ?? 'Customer';

  final RxList<TicketModel> tickets = <TicketModel>[].obs;
  final Rx<TicketStatus?> filter = Rx<TicketStatus?>(null);
  final RxString search = ''.obs;

  final RxList<BookingModel> customerBookings = <BookingModel>[].obs;
  final RxBool loadingBookings = false.obs;

  // Messages for the currently open ticket detail
  final RxList<TicketMessage> messages = <TicketMessage>[].obs;
  StreamSubscription? _msgSub;

  StreamSubscription? _ticketSub;

  @override
  void onInit() {
    super.onInit();
    _listenTickets();
    _loadBookings();
  }

  @override
  void onClose() {
    _ticketSub?.cancel();
    _msgSub?.cancel();
    super.onClose();
  }

  void _listenTickets() {
    _ticketSub?.cancel();
    if (_uid.isEmpty) return;
    _ticketSub =
        _service.userTickets(_uid).listen((list) => tickets.assignAll(list));
  }

  Future<void> _loadBookings() async {
    if (_uid.isEmpty) return;
    loadingBookings.value = true;
    try {
      final stream = _bookingService.customerBookings(_uid);
      stream.first.then((list) {
        customerBookings.assignAll(list);
        loadingBookings.value = false;
      });
    } catch (_) {
      loadingBookings.value = false;
    }
  }

  // ── Filtered list ────────────────────────────────────────────────────

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
              (t.bookingId?.toLowerCase().contains(q) ?? false) ||
              t.description.toLowerCase().contains(q))
          .toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  int get totalUnread =>
      tickets.fold(0, (sum, t) => sum + t.unreadCountCustomer);

  TicketModel? byId(String id) =>
      tickets.firstWhereOrNull((t) => t.id == id);

  // ── Messages for detail screen ───────────────────────────────────────

  void openTicket(String ticketId) {
    _msgSub?.cancel();
    messages.clear();
    _msgSub =
        _service.messagesStream(ticketId).listen((list) => messages.assignAll(list));
    _service.markReadByCustomer(ticketId);
  }

  void closeTicket() {
    _msgSub?.cancel();
    messages.clear();
  }

  // ── Actions ──────────────────────────────────────────────────────────

  Future<String> createTicket({
    required String subject,
    required String description,
    required String category,
    String? bookingId,
    TicketBookingSnapshot? bookingSnapshot,
    String? arenaName,
  }) {
    final ticket = TicketModel(
      id: '',
      subject: subject,
      description: description,
      raisedByUid: _uid,
      raisedByName: _userName,
      raisedByRole: 'customer',
      category: category,
      bookingId: bookingId,
      bookingSnapshot: bookingSnapshot,
      arenaName: arenaName ?? bookingSnapshot?.arenaName,
      createdAt: DateTime.now(),
    );
    return _service.createTicket(ticket);
  }

  Future<void> sendMessage(String ticketId, String content) async {
    if (content.trim().isEmpty) return;
    await _service.sendMessage(
      ticketId,
      senderId: _uid,
      senderName: _userName,
      senderRole: 'customer',
      content: content.trim(),
    );
    await _service.markReadByCustomer(ticketId);
  }

  Future<void> markRead(String ticketId) =>
      _service.markReadByCustomer(ticketId);
}
