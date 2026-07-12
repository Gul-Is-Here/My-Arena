import 'package:get/get.dart';

import '../data/models/ticket_model.dart';

/// Support ticket store — dummy data now, Firestore in the backend phase.
class TicketController extends GetxController {
  static TicketController get to => Get.find();

  final RxList<TicketModel> tickets = <TicketModel>[].obs;

  /// null = all statuses.
  final Rx<TicketStatus?> filter = Rx<TicketStatus?>(null);

  List<TicketModel> get filtered {
    final f = filter.value;
    final list =
        f == null ? tickets.toList() : tickets.where((t) => t.status == f).toList();
    return list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int get openCount =>
      tickets.where((t) => t.status == TicketStatus.open).length;

  TicketModel? byId(String id) => tickets.firstWhereOrNull((t) => t.id == id);

  void _update(String id, TicketModel Function(TicketModel) fn) {
    final i = tickets.indexWhere((t) => t.id == id);
    if (i == -1) return;
    tickets[i] = fn(tickets[i]);
  }

  void setStatus(String id, TicketStatus status) =>
      _update(id, (t) => t.copyWith(status: status));

  void assign(String id, String staffName) => _update(
      id,
      (t) => t.copyWith(
          assignedTo: staffName,
          status: t.status == TicketStatus.open
              ? TicketStatus.inProgress
              : t.status));

  void reply(String id, String message, {String role = 'admin'}) {
    if (message.trim().isEmpty) return;
    _update(
      id,
      (t) => t.copyWith(
        status:
            t.status == TicketStatus.open ? TicketStatus.inProgress : t.status,
        replies: [
          ...t.replies,
          TicketReply(
            id: 'r-${DateTime.now().millisecondsSinceEpoch}',
            senderName: role == 'admin' ? 'Admin' : 'Support',
            senderRole: role,
            message: message.trim(),
            createdAt: DateTime.now(),
          ),
        ],
      ),
    );
  }

  @override
  void onInit() {
    super.onInit();
    _seed();
  }

  void _seed() {
    final now = DateTime.now();
    tickets.assignAll([
      TicketModel(
        id: 'tkt-1001',
        subject: 'Refund not received',
        description:
            'My booking at Smash Indoor Sports was cancelled 3 days ago but the refund has not arrived in my account yet.',
        raisedByName: 'Ali Raza',
        category: 'refund',
        bookingId: '#1042',
        arenaName: 'Smash Indoor Sports',
        status: TicketStatus.open,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      TicketModel(
        id: 'tkt-1002',
        subject: 'Deposit paid but booking still pending',
        description:
            'I sent the JazzCash screenshot yesterday but the owner has not approved my booking.',
        raisedByName: 'Hamza Sheikh',
        category: 'payment',
        bookingId: '#0987',
        arenaName: 'Padel Pro Center',
        status: TicketStatus.inProgress,
        assignedTo: 'Bilal Ahmed',
        createdAt: now.subtract(const Duration(hours: 9)),
        replies: [
          TicketReply(
            id: 'r1',
            senderName: 'Bilal Ahmed',
            senderRole: 'staff',
            message:
                'We have contacted the owner — your payment is being verified.',
            createdAt: now.subtract(const Duration(hours: 6)),
          ),
        ],
      ),
      TicketModel(
        id: 'tkt-1003',
        subject: 'Wrong arena location on map',
        description: 'The pin for my arena points to the wrong street.',
        raisedByName: 'Usman Khalid',
        raisedByRole: 'owner',
        category: 'arena',
        arenaName: 'Padel Pro Center',
        status: TicketStatus.resolved,
        assignedTo: 'Ayesha Tariq',
        createdAt: now.subtract(const Duration(days: 2)),
        replies: [
          TicketReply(
            id: 'r1',
            senderName: 'Ayesha Tariq',
            senderRole: 'staff',
            message: 'Location has been corrected. Please verify.',
            createdAt: now.subtract(const Duration(days: 1)),
          ),
          TicketReply(
            id: 'r2',
            senderName: 'Usman Khalid',
            senderRole: 'owner',
            message: 'Looks good now, thanks!',
            createdAt: now.subtract(const Duration(hours: 20)),
          ),
        ],
      ),
      TicketModel(
        id: 'tkt-1004',
        subject: 'App crashed during checkout',
        raisedByName: 'Sara Malik',
        category: 'other',
        status: TicketStatus.closed,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      TicketModel(
        id: 'tkt-1005',
        subject: 'Charged twice for one booking',
        description: 'I was asked to send the deposit twice for booking #1101.',
        raisedByName: 'Ahmed Nawaz',
        category: 'payment',
        bookingId: '#1101',
        arenaName: 'Champions Arena',
        status: TicketStatus.open,
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
    ]);
  }
}
