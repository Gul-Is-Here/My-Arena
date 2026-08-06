import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../data/models/booking_model.dart';

/// Firestore operations for bookings (Phase 3).
class BookingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _db.collection('bookings');

  // ── Create booking with double-booking prevention ────────────────────

  CollectionReference<Map<String, dynamic>> get _slotLocks =>
      _db.collection('slotLocks');

  /// Atomic slot keys: one document per court-hour.
  /// Key format: {courtId}_{yyyyMMdd}_{HH}
  List<DocumentReference<Map<String, dynamic>>> _slotRefs(
      BookingModel booking) {
    final dateStr =
        '${booking.date.year}${booking.date.month.toString().padLeft(2, '0')}${booking.date.day.toString().padLeft(2, '0')}';
    return List.generate(
      booking.totalHours,
      (i) => _slotLocks
          .doc('${booking.courtId}_${dateStr}_${(booking.startHour + i).toString().padLeft(2, '0')}'),
    );
  }

  Future<String> createBooking(BookingModel booking) async {
    final ref = _bookings.doc();
    final slotRefs = _slotRefs(booking);

    await _db.runTransaction((tx) async {
      // Transactional reads — if any slot doc exists, the court-hour is taken.
      for (final slotRef in slotRefs) {
        final slotSnap = await tx.get(slotRef);
        if (slotSnap.exists) {
          throw Exception(
              'This slot is already booked. Please choose another time.');
        }
      }
      // Reserve every hour atomically.
      for (final slotRef in slotRefs) {
        tx.set(slotRef, {
          'bookingId': ref.id,
          'courtId': booking.courtId,
          'arenaId': booking.arenaId,
          'date': Timestamp.fromDate(
              DateTime(booking.date.year, booking.date.month, booking.date.day)),
        });
      }
      tx.set(ref, {
        ...booking.toMap(),
        'id': ref.id,
        'status': 'pending_deposit',
        'createdAt': FieldValue.serverTimestamp(),
        'startDateTime': Timestamp.fromDate(booking.startDateTime),
      });
    });
    return ref.id;
  }

/// Customer deposit submission — uploads screenshot first, then writes the
  /// booking as deposit_submitted in a single Firestore set. Avoids the
  /// two-step (create pending_deposit → update) race where the second write
  /// could fail after the customer was already shown a success screen.
  Future<String> createBookingWithDeposit(
    BookingModel booking, {
    required File screenshot,
    required String accountUsed,
  }) async {
    final ref = _bookings.doc();

    // 1. Upload screenshot BEFORE touching Firestore, so we have the URL ready.
    debugPrint('📸 [createBookingWithDeposit] uploading screenshot for booking ${ref.id}');
    final uid = FirebaseAuth.instance.currentUser?.uid ?? ref.id;
    final storageRef = _storage.ref(
        'bookings/$uid/deposit_${ref.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await storageRef.putFile(screenshot);
    final screenshotUrl = await storageRef.getDownloadURL();
    debugPrint('📸 [createBookingWithDeposit] screenshot uploaded → $screenshotUrl');

    // 2. Write booking + slot locks atomically.
    debugPrint('📝 [createBookingWithDeposit] writing booking to Firestore…');
    final slotRefs = _slotRefs(booking);
    await _db.runTransaction((tx) async {
      for (final slotRef in slotRefs) {
        final slotSnap = await tx.get(slotRef);
        if (slotSnap.exists) {
          throw Exception(
              'This slot is already booked. Please choose another time.');
        }
      }
      for (final slotRef in slotRefs) {
        tx.set(slotRef, {
          'bookingId': ref.id,
          'courtId': booking.courtId,
          'arenaId': booking.arenaId,
          'date': Timestamp.fromDate(
              DateTime(booking.date.year, booking.date.month, booking.date.day)),
        });
      }
      tx.set(ref, {
        ...booking.toMap(),
        'id': ref.id,
        'status': 'deposit_submitted',
        'createdAt': FieldValue.serverTimestamp(),
        'startDateTime': Timestamp.fromDate(booking.startDateTime),
        'depositPayment': {
          'screenshot': screenshotUrl,
          'accountUsed': accountUsed,
          'submittedAt': FieldValue.serverTimestamp(),
        },
      });
    });
    debugPrint('✅ [createBookingWithDeposit] booking ${ref.id} written as deposit_submitted');
    return ref.id;
  }

  /// Used by owners for manual/walk-in bookings — writes confirmed in one shot,
  /// no transaction needed since payment is taken in person.
  Future<String> createManualBooking(BookingModel booking) async {
    final ref = _bookings.doc();
    final slotRefs = _slotRefs(booking);
    await _db.runTransaction((tx) async {
      for (final slotRef in slotRefs) {
        final slotSnap = await tx.get(slotRef);
        if (slotSnap.exists) {
          throw Exception(
              'This slot is already booked. Please choose another time.');
        }
      }
      for (final slotRef in slotRefs) {
        tx.set(slotRef, {
          'bookingId': ref.id,
          'courtId': booking.courtId,
          'arenaId': booking.arenaId,
          'date': Timestamp.fromDate(
              DateTime(booking.date.year, booking.date.month, booking.date.day)),
        });
      }
      tx.set(ref, {
        ...booking.toMap(),
        'id': ref.id,
        'status': 'confirmed',
        'confirmedBy': booking.ownerId,
        'confirmedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'startDateTime': Timestamp.fromDate(booking.startDateTime),
      });
    });
    return ref.id;
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
    final uid = FirebaseAuth.instance.currentUser?.uid ?? bookingId;
    final ref = _storage.ref(
        'bookings/$uid/deposit_${bookingId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
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
      required Map<String, String> customerAccount}) async {
    // Release slot locks so the court-hours become bookable again.
    final bookingSnap = await _bookings.doc(bookingId).get();
    if (bookingSnap.exists) {
      final booking =
          BookingModel.fromMap({...bookingSnap.data()!, 'id': bookingId});
      final slotRefs = _slotRefs(booking);
      final batch = _db.batch();
      for (final slotRef in slotRefs) {
        batch.delete(slotRef);
      }
      batch.update(_bookings.doc(bookingId), {
        'status': 'cancelled',
        'cancellation.requestedAt': FieldValue.serverTimestamp(),
        'cancellation.refundAmount': refundAmount,
        'cancellation.customerAccount': customerAccount,
        'cancellation.refundStatus': 'pending',
      });
      await batch.commit();
    } else {
      await updateStatus(bookingId, 'cancelled', extra: {
        'cancellation.requestedAt': FieldValue.serverTimestamp(),
        'cancellation.refundAmount': refundAmount,
        'cancellation.customerAccount': customerAccount,
        'cancellation.refundStatus': 'pending',
      });
    }
  }

  Future<void> submitRefund(String bookingId, File screenshot) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? bookingId;
    final ref = _storage.ref(
        'bookings/$uid/refund_${bookingId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(screenshot);
    final url = await ref.getDownloadURL();
    await updateStatus(bookingId, 'refund_sent', extra: {
      'cancellation.refundScreenshot': url,
      'cancellation.refundStatus': 'sent',
    });
  }

  Future<void> submitRefundWithRef(String bookingId, String bankRef) =>
      updateStatus(bookingId, 'refund_sent', extra: {
        'cancellation.refundBankRef': bankRef,
        'cancellation.refundStatus': 'sent',
      });

  Future<void> confirmRefund(String bookingId) =>
      updateStatus(bookingId, 'refund_confirmed', extra: {
        'cancellation.refundStatus': 'confirmed',
      });

  // ── Reschedule ───────────────────────────────────────────────────────

  Future<void> requestReschedule(
    String bookingId, {
    required DateTime proposedDate,
    required int proposedStartHour,
    required int proposedTotalHours,
  }) =>
      _bookings.doc(bookingId).update({
        'status': BookingStatus.rescheduleRequested.key,
        'rescheduleRequest': RescheduleRequest(
          proposedDate: proposedDate,
          proposedStartHour: proposedStartHour,
          proposedTotalHours: proposedTotalHours,
          requestedAt: DateTime.now(),
        ).toMap(),
      });

  /// Owner approves: swap the booking to the proposed date/hours, clear request.
  Future<void> approveReschedule(String bookingId, RescheduleRequest req) =>
      _bookings.doc(bookingId).update({
        'status': BookingStatus.confirmed.key,
        'date': Timestamp.fromDate(req.proposedDate),
        'startHour': req.proposedStartHour,
        'totalHours': req.proposedTotalHours,
        'startTime': '${req.proposedStartHour.toString().padLeft(2, '0')}:00',
        'endTime':
            '${(req.proposedStartHour + req.proposedTotalHours).toString().padLeft(2, '0')}:00',
        'rescheduleRequest': FieldValue.delete(),
      });

  Future<void> rejectReschedule(String bookingId) =>
      _bookings.doc(bookingId).update({
        'status': BookingStatus.confirmed.key,
        'rescheduleRequest': FieldValue.delete(),
      });

  Future<void> checkIn(String bookingId) =>
      _bookings.doc(bookingId).update({
        'checkedIn': true,
        'checkedInAt': FieldValue.serverTimestamp(),
        'status': 'ongoing',
      });

  Future<void> markNoShow(String bookingId) =>
      updateStatus(bookingId, BookingStatus.completed.key, extra: {
        'noShow': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

  Future<void> autoComplete(String bookingId, {bool noShow = false}) =>
      updateStatus(bookingId, BookingStatus.completed.key, extra: {
        'completedAt': FieldValue.serverTimestamp(),
        if (noShow) 'noShow': true,
      });

  // ── Recurring ────────────────────────────────────────────────────────

  /// Creates [totalWeeks] weekly bookings starting from [first].
  /// Returns the list of created booking IDs. Stops and rethrows on the
  /// first slot conflict so partial series creation is avoided where possible.
  Future<List<String>> createRecurringBookings(
    BookingModel first,
    int totalWeeks, {
    File? depositScreenshot,
    String? depositAccount,
  }) async {
    final ids = <String>[];
    for (var week = 1; week <= totalWeeks; week++) {
      final weekDate = first.date.add(Duration(days: 7 * (week - 1)));
      final weekBooking = BookingModel(
        id: '',
        arenaId: first.arenaId,
        arenaName: first.arenaName,
        courtId: first.courtId,
        courtName: first.courtName,
        customerId: first.customerId,
        customerName: first.customerName,
        ownerId: first.ownerId,
        date: DateTime(weekDate.year, weekDate.month, weekDate.day),
        startHour: first.startHour,
        totalHours: first.totalHours,
        pricePerHour: first.pricePerHour,
        totalAmountStored: first.totalAmountStored,
        createdAt: DateTime.now(),
        recurringGroupId: first.recurringGroupId,
        recurringWeek: week,
        recurringTotal: totalWeeks,
        isGroupBooking: first.isGroupBooking,
        groupSize: first.groupSize,
        joinCode: first.joinCode,
      );

      try {
        // First week: submit deposit so it enters the approval queue.
        // Remaining weeks: create as pending_deposit for later individual payment.
        if (week == 1 && depositScreenshot != null && depositAccount != null) {
          final id = await createBookingWithDeposit(
            weekBooking,
            screenshot: depositScreenshot,
            accountUsed: depositAccount,
          );
          ids.add(id);
        } else {
          final id = await createBooking(weekBooking);
          ids.add(id);
        }
      } catch (e) {
        // Slot conflict on a future week — surface it with context.
        throw Exception(
            'Week $week (${_shortDate(weekDate)}) is already booked. Series partially created (${ids.length}/${totalWeeks} weeks).');
      }
    }
    return ids;
  }

  String _shortDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  /// Cancel all bookings in a recurring series.
  Future<void> cancelRecurringSeries(
    String recurringGroupId,
    String customerId,
  ) async {
    final snap = await _bookings
        .where('recurringGroupId', isEqualTo: recurringGroupId)
        .where('customerId', isEqualTo: customerId)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      final data = doc.data();
      final status = data['status'] as String? ?? '';
      if (['cancelled', 'completed', 'rejected'].contains(status)) continue;
      batch.update(doc.reference, {
        'status': 'cancelled',
        'cancellation.requestedAt': FieldValue.serverTimestamp(),
        'cancellation.reason': 'Series cancelled by customer',
      });
    }
    await batch.commit();
  }

  // ── Group booking ─────────────────────────────────────────────────────

  /// Finds a group booking by [joinCode] and adds [userId] as a member.
  Future<BookingModel?> joinGroupBooking(
    String joinCode,
    String userId,
    String userName,
  ) async {
    final snap = await _bookings
        .where('joinCode', isEqualTo: joinCode.toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    await doc.reference.update({
      'groupMembers': FieldValue.arrayUnion([
        {'userId': userId, 'name': userName, 'joinedAt': Timestamp.now()},
      ]),
    });
    return BookingModel.fromMap({...doc.data(), 'id': doc.id});
  }

  // ── Waitlist ──────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> waitlistItems(String customerId) =>
      _db
          .collection('waitlist')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList());

  Future<void> cancelWaitlistItem(String docId) =>
      _db.collection('waitlist').doc(docId).delete();

  // ── Queries ──────────────────────────────────────────────────────────

  /// Bookings across a list of arena IDs — used by arena staff who are not
  /// the owner. Firestore `whereIn` supports up to 30 values.
  Stream<List<BookingModel>> staffBookings(List<String> arenaIds,
          {int limit = 200}) {
    final ids = arenaIds.take(30).toList();
    if (ids.isEmpty) {
      return Stream.value([]);
    }
    return _bookings
        .where('arenaId', whereIn: ids)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs
            .map((d) => BookingModel.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Stream<List<BookingModel>> ownerBookings(String ownerId,
          {int limit = 200}) =>
      _bookings
          .where('ownerId', isEqualTo: ownerId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
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

  /// All bookings between one customer and one arena — powers the live
  /// booking-context banner in the pair chat. Equality-only filters, so no
  /// composite index is needed; callers sort client-side.
  Stream<List<BookingModel>> pairBookings(String arenaId, String customerId) =>
      _bookings
          .where('arenaId', isEqualTo: arenaId)
          .where('customerId', isEqualTo: customerId)
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
