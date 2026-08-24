import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/models/booking_model.dart';
import '../data/models/extension_request_model.dart';

class ExtensionService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('extensionRequests');

  CollectionReference<Map<String, dynamic>> get _slotLocks =>
      _db.collection('slotLocks');

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _db.collection('bookings');

  /// Customer submits an extension request.
  Future<void> createRequest(BookingModel booking, int minutes) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await _requests.add({
      ...ExtensionRequestModel(
        id: '',
        bookingId: booking.id,
        customerId: uid,
        customerName: booking.customerName,
        ownerId: booking.ownerId,
        arenaId: booking.arenaId,
        courtId: booking.courtId,
        courtName: booking.courtName,
        extensionMinutes: minutes,
        requestedAt: DateTime.now(),
        status: ExtensionRequestStatus.pending,
      ).toMap(),
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Customer cancels their own pending request.
  Future<void> cancelRequest(String requestId) =>
      _requests.doc(requestId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

  /// Stream of extension requests for a specific booking (customer view).
  Stream<List<ExtensionRequestModel>> bookingRequestsStream(String bookingId) =>
      _requests
          .where('bookingId', isEqualTo: bookingId)
          .orderBy('requestedAt', descending: true)
          .limit(5)
          .snapshots()
          .map((s) => s.docs
              .map((d) => ExtensionRequestModel.fromMap(d.data(), d.id))
              .toList());

  /// Stream of pending extension requests for an owner's arena (owner view).
  Stream<List<ExtensionRequestModel>> ownerPendingStream(String arenaId) =>
      _requests
          .where('arenaId', isEqualTo: arenaId)
          .where('status', isEqualTo: 'pending')
          .orderBy('requestedAt')
          .snapshots()
          .map((s) => s.docs
              .map((d) => ExtensionRequestModel.fromMap(d.data(), d.id))
              .toList());

  /// Owner approves an extension request.
  /// Runs a Firestore transaction that checks for slot conflicts before writing.
  Future<void> approveRequest(ExtensionRequestModel req) async {
    final bookingRef = _bookings.doc(req.bookingId);
    final requestRef = _requests.doc(req.id);

    // Compute the hour range that needs to be free.
    // We fetch the booking first (outside transaction) to build slot lock refs,
    // then re-verify inside the transaction.
    final bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) throw Exception('Booking not found');
    final booking =
        BookingModel.fromMap({...bookingSnap.data()!, 'id': req.bookingId});

    if (booking.status != BookingStatus.ongoing) {
      throw Exception('Booking is no longer active');
    }

    final currentEndMinutes =
        (booking.startHour + booking.totalHours) * 60 + booking.extensionMinutes;
    final newEndMinutes = currentEndMinutes + req.extensionMinutes;

    // Build slot lock document IDs for each hour the extension would enter.
    final dateStr =
        '${booking.date.year}${booking.date.month.toString().padLeft(2, '0')}${booking.date.day.toString().padLeft(2, '0')}';
    final startCheckHour = currentEndMinutes ~/ 60;
    final endCheckHour = (newEndMinutes - 1) ~/ 60;

    final lockRefs = <DocumentReference<Map<String, dynamic>>>[];
    for (var h = startCheckHour; h <= endCheckHour; h++) {
      lockRefs.add(_slotLocks
          .doc('${booking.courtId}_${dateStr}_${h.toString().padLeft(2, '0')}'));
    }

    await _db.runTransaction((tx) async {
      // Verify booking still ongoing and request still pending.
      final bSnap = await tx.get(bookingRef);
      final rSnap = await tx.get(requestRef);
      if (bSnap.data()?['status'] != 'ongoing') {
        throw Exception('Booking is no longer active');
      }
      if (rSnap.data()?['status'] != 'pending') {
        throw Exception('Request is no longer pending');
      }

      // Check each lock — if it exists and belongs to a different booking → conflict.
      for (final lockRef in lockRefs) {
        final lockSnap = await tx.get(lockRef);
        if (lockSnap.exists &&
            lockSnap.data()?['bookingId'] != req.bookingId) {
          throw Exception(
              'The ${lockRef.id.split('_').last}:00 slot is already booked — cannot extend');
        }
      }

      // All clear: update extensionMinutes on the booking.
      final newExtension = newEndMinutes -
          (booking.startHour + booking.totalHours) * 60;
      tx.update(bookingRef, {'extensionMinutes': newExtension});
      tx.update(requestRef, {
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Owner rejects an extension request.
  Future<void> rejectRequest(String requestId) =>
      _requests.doc(requestId).update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
      });
}
