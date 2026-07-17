import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../data/models/booking_model.dart';

/// Firestore operations for bookings (Phase 3).
class BookingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _db.collection('bookings');

  // ── Create booking with double-booking prevention ────────────────────

  Future<String> createBooking(BookingModel booking) async {
    final ref = _bookings.doc();
    await _db.runTransaction((tx) async {
      // Check for overlapping bookings on same court + date.
      final overlap = await _bookings
          .where('courtId', isEqualTo: booking.courtId)
          .where('date',
              isEqualTo: Timestamp.fromDate(DateTime(
                booking.date.year,
                booking.date.month,
                booking.date.day,
              )))
          .where('status',
              whereIn: ['pending_deposit', 'deposit_submitted', 'confirmed'])
          .get();

      for (final doc in overlap.docs) {
        final b = BookingModel.fromMap({...doc.data(), 'id': doc.id});
        // Check time overlap.
        if (_timesOverlap(
            booking.startTime, booking.endTime, b.startTime, b.endTime)) {
          throw Exception('This slot is already booked. Please choose another time.');
        }
      }
      tx.set(ref, {
        ...booking.toMap(),
        'id': ref.id,
        'status': 'pending_deposit',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return ref.id;
  }

  bool _timesOverlap(
      String s1, String e1, String s2, String e2) {
    int toMin(String t) {
      final p = t.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    final s1m = toMin(s1), e1m = toMin(e1);
    final s2m = toMin(s2), e2m = toMin(e2);
    return s1m < e2m && e1m > s2m;
  }

  // ── Status transitions ───────────────────────────────────────────────

  Future<void> updateStatus(String bookingId, String status,
          {Map<String, dynamic>? extra}) =>
      _bookings.doc(bookingId).update({
        'status': status,
        ...?extra,
      });

  Future<void> submitDeposit(String bookingId,
      {required File screenshot, required String accountUsed}) async {
    final ref = _storage.ref(
        'bookings/$bookingId/deposit_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(screenshot);
    final url = await ref.getDownloadURL();
    await updateStatus(bookingId, 'deposit_submitted', extra: {
      'depositPayment': {
        'screenshot': url,
        'accountUsed': accountUsed,
        'submittedAt': FieldValue.serverTimestamp(),
      }
    });
  }

  Future<void> confirmBooking(String bookingId, String confirmedBy) =>
      updateStatus(bookingId, 'confirmed',
          extra: {'confirmedBy': confirmedBy});

  Future<void> rejectBooking(String bookingId) =>
      updateStatus(bookingId, 'rejected');

  Future<void> cancelBooking(String bookingId,
      {required double refundAmount,
      required Map<String, String> customerAccount}) =>
      updateStatus(bookingId, 'cancelled', extra: {
        'cancellation.requestedAt': FieldValue.serverTimestamp(),
        'cancellation.refundAmount': refundAmount,
        'cancellation.customerAccount': customerAccount,
        'cancellation.refundStatus': 'pending',
      });

  Future<void> submitRefund(String bookingId, File screenshot) async {
    final ref = _storage.ref(
        'bookings/$bookingId/refund_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(screenshot);
    final url = await ref.getDownloadURL();
    await updateStatus(bookingId, 'refund_sent', extra: {
      'cancellation.refundScreenshot': url,
      'cancellation.refundStatus': 'sent',
    });
  }

  Future<void> confirmRefund(String bookingId) =>
      updateStatus(bookingId, 'refund_confirmed', extra: {
        'cancellation.refundStatus': 'confirmed',
      });

  // ── Queries ──────────────────────────────────────────────────────────

  Stream<List<BookingModel>> ownerBookings(String ownerId) => _bookings
      .where('ownerId', isEqualTo: ownerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => BookingModel.fromMap({...d.data(), 'id': d.id}))
          .toList());

  Stream<List<BookingModel>> customerBookings(String customerId) => _bookings
      .where('customerId', isEqualTo: customerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => BookingModel.fromMap({...d.data(), 'id': d.id}))
          .toList());

  Stream<List<BookingModel>> arenaBookings(String arenaId) => _bookings
      .where('arenaId', isEqualTo: arenaId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => BookingModel.fromMap({...d.data(), 'id': d.id}))
          .toList());

  Stream<List<BookingModel>> pendingDepositBookings(String arenaId) =>
      _bookings
          .where('arenaId', isEqualTo: arenaId)
          .where('status', isEqualTo: 'deposit_submitted')
          .snapshots()
          .map((s) => s.docs
              .map((d) => BookingModel.fromMap({...d.data(), 'id': d.id}))
              .toList());

  /// Booked slots for a court on a specific date (for slot grid).
  Future<List<BookingModel>> bookedSlots(
      String courtId, DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final snap = await _bookings
        .where('courtId', isEqualTo: courtId)
        .where('date', isEqualTo: Timestamp.fromDate(day))
        .where('status',
            whereIn: ['pending_deposit', 'deposit_submitted', 'confirmed'])
        .get();
    return snap.docs
        .map((d) => BookingModel.fromMap({...d.data(), 'id': d.id}))
        .toList();
  }
}
