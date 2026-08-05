import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/ticket_model.dart';

class TicketService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('tickets');

  CollectionReference<Map<String, dynamic>> _messages(String ticketId) =>
      _col.doc(ticketId).collection('messages');

  // ── Ticket number generation ─────────────────────────────────────────

  String _nextTicketNumber() {
    final now = DateTime.now();
    final ts = '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    return 'TK-${now.year}$ts';
  }

  // ── Streams ──────────────────────────────────────────────────────────

  Stream<List<TicketModel>> allTickets() => _col
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map(_mapDocs);

  Stream<List<TicketModel>> userTickets(String uid) => _col
      .where('raisedByUid', isEqualTo: uid)
      .snapshots()
      .map(_mapDocs);

  Stream<List<TicketMessage>> messagesStream(String ticketId) =>
      _messages(ticketId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((s) => s.docs
              .map((d) => TicketMessage.fromMap(d.data(), d.id))
              .toList());

  List<TicketModel> _mapDocs(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs
          .map((d) => TicketModel.fromMap({...d.data(), 'id': d.id}))
          .toList();

  // ── Create ───────────────────────────────────────────────────────────

  Future<String> createTicket(TicketModel ticket) async {
    final number = _nextTicketNumber();
    final ref = _col.doc();
    final now = DateTime.now();

    final initialHistory = StatusChange(
      status: TicketStatus.open.key,
      changedBy: ticket.raisedByName,
      changedByRole: ticket.raisedByRole,
      changedAt: now,
    );

    final data = {
      ...ticket.toMap(),
      'id': ref.id,
      'ticketNumber': number,
      'statusHistory': [initialHistory.toMap()],
    };
    await ref.set(data);

    // Auto-add system message
    await _messages(ref.id).add(TicketMessage(
      id: '',
      senderId: 'system',
      senderName: 'System',
      senderRole: 'system',
      type: TicketMessageType.system,
      content: 'Ticket $number created. Our support team will respond shortly.',
      createdAt: now,
    ).toMap());

    return ref.id;
  }

  // ── Messages ─────────────────────────────────────────────────────────

  Future<void> sendMessage(
    String ticketId, {
    required String senderId,
    required String senderName,
    required String senderRole,
    required String content,
    TicketMessageType type = TicketMessageType.text,
    String? fileName,
  }) async {
    final isAdmin = senderRole == 'admin' || senderRole == 'staff';
    final msg = TicketMessage(
      id: '',
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      type: type,
      content: content,
      fileName: fileName,
      isReadByAdmin: isAdmin,
      isReadByCustomer: !isAdmin,
      createdAt: DateTime.now(),
    );
    await _messages(ticketId).add(msg.toMap());

    // Update ticket: lastMessage, updatedAt, increment unread count
    await _col.doc(ticketId).update({
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': content,
      if (isAdmin)
        'unreadCountCustomer': FieldValue.increment(1)
      else
        'unreadCountAdmin': FieldValue.increment(1),
    });
  }

  // ── Mark read ────────────────────────────────────────────────────────

  Future<void> markReadByCustomer(String ticketId) =>
      _col.doc(ticketId).update({'unreadCountCustomer': 0});

  Future<void> markReadByAdmin(String ticketId) =>
      _col.doc(ticketId).update({'unreadCountAdmin': 0});

  // ── Status / assignment ──────────────────────────────────────────────

  Future<void> updateStatus(
    String ticketId,
    TicketStatus status, {
    required String changedBy,
    required String changedByRole,
  }) async {
    final change = StatusChange(
      status: status.key,
      changedBy: changedBy,
      changedByRole: changedByRole,
      changedAt: DateTime.now(),
    );
    await _col.doc(ticketId).update({
      'status': status.key,
      'updatedAt': FieldValue.serverTimestamp(),
      'statusHistory': FieldValue.arrayUnion([change.toMap()]),
    });
    // System message in subcollection
    await _messages(ticketId).add(TicketMessage(
      id: '',
      senderId: 'system',
      senderName: 'System',
      senderRole: 'system',
      type: TicketMessageType.system,
      content: 'Status changed to: ${status.label}',
      createdAt: DateTime.now(),
    ).toMap());
  }

  Future<void> assign(
    String ticketId,
    String staffName,
    String staffUid,
  ) async {
    await _col.doc(ticketId).update({
      'assignedTo': staffName,
      'assignedToUid': staffUid,
      'status': TicketStatus.inProgress.key,
      'updatedAt': FieldValue.serverTimestamp(),
      'statusHistory': FieldValue.arrayUnion([
        StatusChange(
          status: TicketStatus.inProgress.key,
          changedBy: staffName,
          changedByRole: 'admin',
          changedAt: DateTime.now(),
        ).toMap(),
      ]),
    });
  }

  Future<void> setPriority(String ticketId, TicketPriority priority) =>
      _col.doc(ticketId).update({
        'priority': priority.key,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // ── Legacy reply (admin detail screen still uses this) ───────────────

  Future<void> addReply(String id, TicketReply reply) => _col.doc(id).update({
        'replies': FieldValue.arrayUnion([reply.toMap()]),
        'status': TicketStatus.inProgress.key,
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
