import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/ticket_model.dart';

class TicketService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('tickets');

  // ── Streams ──────────────────────────────────────────────────────────

  Stream<List<TicketModel>> allTickets() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(_mapDocs);

  Stream<List<TicketModel>> userTickets(String uid) => _col
      .where('raisedByUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(_mapDocs);

  List<TicketModel> _mapDocs(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs
          .map((d) => TicketModel.fromMap({...d.data(), 'id': d.id}))
          .toList();

  // ── Writes ───────────────────────────────────────────────────────────

  Future<String> createTicket(TicketModel ticket) async {
    final ref = _col.doc();
    await ref.set({...ticket.toMap(), 'id': ref.id});
    return ref.id;
  }

  Future<void> updateStatus(String id, TicketStatus status) =>
      _col.doc(id).update({'status': status.key});

  Future<void> assign(String id, String staffName) => _col.doc(id).update({
        'assignedTo': staffName,
        'status': TicketStatus.inProgress.key,
      });

  Future<void> addReply(String id, TicketReply reply) => _col.doc(id).update({
        'replies': FieldValue.arrayUnion([reply.toMap()]),
        'status': TicketStatus.inProgress.key,
      });
}
