import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/booking_model.dart';
import '../data/models/pos_transaction_model.dart';
import '../data/models/recurring_series_model.dart';
import 'ledger_service.dart';

/// Wraps [FirebaseFirestore.runTransaction] and silently discards the
/// `MissingPluginException` that the cloud_firestore Android SDK throws when
/// tearing down a completed transaction's EventChannel. The transaction itself
/// has already committed by that point, so the exception is safe to ignore.
Future<T> _runTx<T>(
  FirebaseFirestore db,
  Future<T> Function(Transaction) updateFunction,
) async {
  try {
    return await db.runTransaction(updateFunction);
  } on MissingPluginException {
    // Android cloud_firestore bug: EventChannel cancel fires after the
    // transaction succeeds. Data is already written — rethrow nothing.
    return null as T;
  }
}

/// Firestore operations for bookings (Phase 3).
class BookingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _db.collection('bookings');

  CollectionReference<Map<String, dynamic>> get _series =>
      _db.collection('recurringBookingSeries');

  // ── Recurring series streams ──────────────────────────────────────────

  Stream<RecurringSeriesModel?> seriesStream(String seriesId) => _series
      .doc(seriesId)
      .snapshots()
      .map((s) => s.exists
          ? RecurringSeriesModel.fromMap({...s.data()!, 'id': s.id})
          : null);

  Stream<List<RecurringSeriesModel>> customerSeriesStream(String customerId) =>
      _series
          .where('customerId', isEqualTo: customerId)
          .orderBy('startDate', descending: false)
          .snapshots()
          .map((s) => s.docs
              .map((d) =>
                  RecurringSeriesModel.fromMap({...d.data(), 'id': d.id}))
              .toList());

  Stream<List<RecurringSeriesModel>> ownerSeriesStream(String ownerId) =>
      _series
          .where('ownerId', isEqualTo: ownerId)
          .where('status', whereIn: ['pending', 'confirmed', 'partially_confirmed'])
          .orderBy('startDate', descending: false)
          .snapshots()
          .map((s) => s.docs
              .map((d) =>
                  RecurringSeriesModel.fromMap({...d.data(), 'id': d.id}))
              .toList());

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

    await _runTx(_db, (tx) async {
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
          'customerId': booking.customerId,
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
    required XFile screenshot,
    required String accountUsed,
  }) async {
    final ref = _bookings.doc();

    // 1. Upload screenshot BEFORE touching Firestore, so we have the URL ready.
    debugPrint('📸 [createBookingWithDeposit] uploading screenshot for booking ${ref.id}');
    final uid = FirebaseAuth.instance.currentUser?.uid ?? ref.id;
    final storageRef = _storage.ref(
        'bookings/$uid/deposit_${ref.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await storageRef.putData(await screenshot.readAsBytes());
    final screenshotUrl = await storageRef.getDownloadURL();
    debugPrint('📸 [createBookingWithDeposit] screenshot uploaded → $screenshotUrl');

    // 2. Write booking + slot locks atomically.
    debugPrint('📝 [createBookingWithDeposit] writing booking to Firestore…');
    final slotRefs = _slotRefs(booking);
    await _runTx(_db, (tx) async {
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
          'customerId': booking.customerId,
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
    await _runTx(_db, (tx) async {
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
          'customerId': booking.customerId,
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
      {required XFile screenshot, required String accountUsed}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? bookingId;
    final ref = _storage.ref(
        'bookings/$uid/deposit_${bookingId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(await screenshot.readAsBytes());
    final url = await ref.getDownloadURL();
    await updateStatus(bookingId, 'deposit_submitted', extra: {
      'depositPayment': {
        'screenshot': url,
        'accountUsed': accountUsed,
        'submittedAt': FieldValue.serverTimestamp(),
      }
    });
  }

  Future<void> confirmBooking(String bookingId, String confirmedBy) async {
    // Fetch the booking so we can build a ledger entry with financial context.
    final snap = await _bookings.doc(bookingId).get();
    final booking = snap.exists
        ? BookingModel.fromMap({...snap.data()!, 'id': bookingId})
        : null;

    final batch = _db.batch();
    batch.update(_bookings.doc(bookingId), {
      'status': 'confirmed',
      'confirmedBy': confirmedBy,
    });

    // For online bookings only: write a ledger entry so revenue is visible
    // in the unified POS ledger. Pre-check the idempotency key to avoid
    // duplicates on retry (tiny race window is acceptable for Phase 1).
    if (booking != null && !booking.isPosBooking) {
      final ikey = '${bookingId}_confirmed';
      final existing = await _db
          .collection('posTransactions')
          .where('idempotencyKey', isEqualTo: ikey)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        final ledger = LedgerService();
        final entry = ledger.entryForConfirmedBooking(
          booking,
          confirmedBy,
          '',
          confirmedByRole: 'owner',
        );
        final ledgerRef = _db.collection('posTransactions').doc();
        batch.set(ledgerRef, {...entry.toMap(), 'id': ledgerRef.id});
      }
    }

    await batch.commit();
  }

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

  Future<void> submitRefund(String bookingId, XFile screenshot) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? bookingId;
    final ref = _storage.ref(
        'bookings/$uid/refund_${bookingId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(await screenshot.readAsBytes());
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

  /// Owner approves: atomically delete old slot locks, write new ones, and
  /// update the booking. Without the lock swap, the old hours stay blocked
  /// and the new hours are unprotected — fixed here with a transaction.
  Future<void> approveReschedule(String bookingId, RescheduleRequest req) async {
    final snap = await _bookings.doc(bookingId).get();
    if (!snap.exists) throw Exception('Booking not found');
    final booking = BookingModel.fromMap({...snap.data()!, 'id': bookingId});

    final oldSlotRefs = _slotRefs(booking);
    final dateStr =
        '${req.proposedDate.year}${req.proposedDate.month.toString().padLeft(2, '0')}${req.proposedDate.day.toString().padLeft(2, '0')}';
    final newSlotRefs = List.generate(
      req.proposedTotalHours,
      (i) => _slotLocks.doc(
          '${booking.courtId}_${dateStr}_${(req.proposedStartHour + i).toString().padLeft(2, '0')}'),
    );

    await _runTx(_db, (tx) async {
      for (final slotRef in newSlotRefs) {
        final slotSnap = await tx.get(slotRef);
        if (slotSnap.exists && slotSnap.data()?['bookingId'] != bookingId) {
          throw Exception('The requested slot is already taken');
        }
      }
      for (final oldRef in oldSlotRefs) {
        tx.delete(oldRef);
      }
      for (final newRef in newSlotRefs) {
        tx.set(newRef, {
          'bookingId': bookingId,
          'courtId': booking.courtId,
          'arenaId': booking.arenaId,
          'customerId': booking.customerId,
          'date': Timestamp.fromDate(DateTime(
              req.proposedDate.year, req.proposedDate.month, req.proposedDate.day)),
        });
      }
      tx.update(_bookings.doc(bookingId), {
        'status': BookingStatus.confirmed.key,
        'date': Timestamp.fromDate(req.proposedDate),
        'startHour': req.proposedStartHour,
        'totalHours': req.proposedTotalHours,
        'startTime': '${req.proposedStartHour.toString().padLeft(2, '0')}:00',
        'endTime':
            '${(req.proposedStartHour + req.proposedTotalHours).toString().padLeft(2, '0')}:00',
        'rescheduleRequest': FieldValue.delete(),
      });
    });
  }

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

  /// Atomically: write slot locks for the new hours, increment totalHours,
  /// update totalAmount (stored) and remainingAmount on the booking.
  Future<void> extendSession(BookingModel booking, int extraHours) async {
    final dateStr =
        '${booking.date.year}${booking.date.month.toString().padLeft(2, '0')}${booking.date.day.toString().padLeft(2, '0')}';
    final currentEnd = booking.startHour + booking.totalHours;
    final newSlotRefs = List.generate(
      extraHours,
      (i) => _slotLocks.doc(
          '${booking.courtId}_${dateStr}_${(currentEnd + i).toString().padLeft(2, '0')}'),
    );
    final oldStored =
        booking.totalAmountStored ?? booking.pricePerHour * booking.totalHours;
    final newTotalStored = oldStored + extraHours * booking.pricePerHour;
    final newTotal = newTotalStored + booking.posAddOnsTotal - booking.posDiscount;
    final newRemaining =
        (newTotal - (booking.amountPaid ?? 0)).clamp(0.0, double.infinity);

    await _runTx(_db, (tx) async {
      for (final slotRef in newSlotRefs) {
        final snap = await tx.get(slotRef);
        if (snap.exists) {
          throw Exception('Next slot is already booked — cannot extend');
        }
      }
      for (final slotRef in newSlotRefs) {
        tx.set(slotRef, {
          'bookingId': booking.id,
          'courtId': booking.courtId,
          'arenaId': booking.arenaId,
          'customerId': booking.customerId,
          'date': Timestamp.fromDate(
              DateTime(booking.date.year, booking.date.month, booking.date.day)),
        });
      }
      tx.update(_bookings.doc(booking.id), {
        'totalHours': FieldValue.increment(extraHours),
        'totalAmount': newTotalStored,
        'remainingAmount': newRemaining,
      });
    });
  }

  /// Completes the session: increments amountPaid, writes the final
  /// remainingAmount, and sets status + completedAt atomically.
  /// Also writes a ledger entry for the amount collected so POS stats reflect it.
  Future<void> checkoutSession(
    String bookingId,
    double amountCollected,
    double newRemainingAmount, {
    BookingModel? booking,
    String? shiftId,
  }) async {
    final batch = _db.batch();
    batch.update(_bookings.doc(bookingId), {
      'status': BookingStatus.completed.key,
      'completedAt': FieldValue.serverTimestamp(),
      'amountPaid': FieldValue.increment(amountCollected),
      'remainingAmount': newRemainingAmount.clamp(0.0, double.infinity),
    });

    if (booking != null && amountCollected > 0) {
      final ikey = '${bookingId}_checkout';
      final existing = await _db
          .collection('posTransactions')
          .where('idempotencyKey', isEqualTo: ikey)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        final entry = PosTransactionModel(
          id: '',
          arenaId: booking.arenaId,
          arenaName: booking.arenaName,
          bookingId: bookingId,
          courtId: booking.courtId,
          courtName: booking.courtName,
          customerId: booking.customerId.isEmpty ? null : booking.customerId,
          customerName: booking.customerName,
          type: PosTransactionType.checkout,
          source: LedgerSource.pos, // always counter collection regardless of booking origin
          paymentMethod: PosPaymentMethod.cash,
          totalAmount: booking.totalAmount,
          amountPaid: amountCollected,
          remainingAmount: newRemainingAmount.clamp(0.0, double.infinity),
          processedById: '',
          processedByName: '',
          processedByRole: 'owner',
          createdAt: DateTime.now(),
          shiftId: shiftId,
          idempotencyKey: ikey,
          notes: 'Session checkout',
        );
        final ledgerRef = _db.collection('posTransactions').doc();
        batch.set(ledgerRef, {...entry.toMap(), 'id': ledgerRef.id});
      }
    }

    await batch.commit();
  }

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
    XFile? depositScreenshot,
    String? depositAccount,
  }) async {
    // ── Pre-validation: check every week's slots BEFORE writing anything ──
    // This prevents partial series creation where week 1 succeeds but week 3
    // is already booked — an all-or-nothing check.
    for (var week = 1; week <= totalWeeks; week++) {
      final weekDate = first.date.add(Duration(days: 7 * (week - 1)));
      final dateStr =
          '${weekDate.year}${weekDate.month.toString().padLeft(2, '0')}${weekDate.day.toString().padLeft(2, '0')}';
      for (var h = 0; h < first.totalHours; h++) {
        final key =
            '${first.courtId}_${dateStr}_${(first.startHour + h).toString().padLeft(2, '0')}';
        final snap = await _slotLocks.doc(key).get();
        if (snap.exists) {
          throw Exception(
              'Week $week (${_shortDate(weekDate)}) is already booked. No bookings were created — please choose a different slot.');
        }
      }
    }

    // ── Upload screenshot once for the whole series ──
    // (Previously uploaded per-week, causing 4× storage cost and 4 Firestore
    // transactions with their attendant MissingPluginException cleanup noise.)
    String? screenshotUrl;
    if (depositScreenshot != null && depositAccount != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final storageRef = _storage.ref(
          'bookings/$uid/deposit_series_${first.recurringGroupId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putData(await depositScreenshot.readAsBytes());
      screenshotUrl = await storageRef.getDownloadURL();
      debugPrint('📸 [createRecurringBookings] series screenshot → $screenshotUrl');
    }

    // ── Build week bookings + pre-allocated doc refs ──
    final weekBookings = <BookingModel>[];
    final refs = <DocumentReference<Map<String, dynamic>>>[];
    for (var week = 1; week <= totalWeeks; week++) {
      final weekDate = first.date.add(Duration(days: 7 * (week - 1)));
      weekBookings.add(BookingModel(
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
        appliedPromoId: week == 1 ? first.appliedPromoId : null,
        appliedPromoCode: week == 1 ? first.appliedPromoCode : null,
        promoDiscount: week == 1 ? first.promoDiscount : 0,
        appliedPromoScope: week == 1 ? first.appliedPromoScope : null,
      ));
      refs.add(_bookings.doc());
    }

    // ── Prepare series document ref (same ID as recurringGroupId) ──
    final seriesRef = _series.doc(first.recurringGroupId);
    final endDate = weekBookings.last.date;
    final paymentStatusKey = screenshotUrl != null
        ? PaymentStatus.depositSubmitted.key
        : PaymentStatus.unpaid.key;

    // ── Single transaction: verify all slots + write all weeks + series doc ──
    // One transaction instead of N reduces MissingPluginException cleanup
    // events from N to 1 (known cloud_firestore Android platform-channel bug).
    await _runTx(_db, (tx) async {
      for (var i = 0; i < weekBookings.length; i++) {
        for (final slotRef in _slotRefs(weekBookings[i])) {
          final snap = await tx.get(slotRef);
          if (snap.exists) {
            throw Exception(
                'Week ${i + 1} slot was just taken. No bookings were created — please choose a different time.');
          }
        }
      }
      for (var i = 0; i < weekBookings.length; i++) {
        final wb = weekBookings[i];
        for (final slotRef in _slotRefs(wb)) {
          tx.set(slotRef, {
            'bookingId': refs[i].id,
            'courtId': wb.courtId,
            'arenaId': wb.arenaId,
            'customerId': wb.customerId,
            'date': Timestamp.fromDate(
                DateTime(wb.date.year, wb.date.month, wb.date.day)),
          });
        }
        tx.set(refs[i], {
          ...wb.toMap(),
          'id': refs[i].id,
          'status': screenshotUrl != null ? 'deposit_submitted' : 'pending_deposit',
          'paymentStatus': paymentStatusKey,
          'createdAt': FieldValue.serverTimestamp(),
          'startDateTime': Timestamp.fromDate(wb.startDateTime),
          if (screenshotUrl != null)
            'depositPayment': {
              'screenshot': screenshotUrl,
              'accountUsed': depositAccount,
              'submittedAt': FieldValue.serverTimestamp(),
            },
        });
      }
      // Series document — one canonical record for the whole recurring booking.
      // Written with the same ID as recurringGroupId so any booking can link back.
      tx.set(seriesRef, {
        'id': first.recurringGroupId,
        'customerId': first.customerId,
        'customerName': first.customerName,
        'arenaId': first.arenaId,
        'arenaName': first.arenaName,
        'courtId': first.courtId,
        'courtName': first.courtName,
        'ownerId': first.ownerId,
        'frequency': 'weekly',
        'startDate': Timestamp.fromDate(weekBookings.first.date),
        'endDate': Timestamp.fromDate(endDate),
        'totalOccurrences': weekBookings.length,
        'status': 'pending',
        'confirmedCount': 0,
        'startHour': first.startHour,
        'totalHours': first.totalHours,
        'firstBookingId': refs.first.id,
        if (screenshotUrl != null) 'depositScreenshotUrl': screenshotUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    debugPrint('✅ [createRecurringBookings] ${weekBookings.length} weeks + series doc written atomically');
    return refs.map((r) => r.id).toList();
  }

  String _shortDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  /// Cancel all future-eligible bookings in a recurring series.
  /// Completed historical occurrences are left unchanged.
  Future<void> cancelRecurringSeries(
    String recurringGroupId,
    String customerId,
  ) async {
    final snap = await _bookings
        .where('recurringGroupId', isEqualTo: recurringGroupId)
        .where('customerId', isEqualTo: customerId)
        .get();
    final batch = _db.batch();
    int cancelledCount = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final status = data['status'] as String? ?? '';
      if (['cancelled', 'completed', 'rejected'].contains(status)) continue;
      batch.update(doc.reference, {
        'status': 'cancelled',
        'cancellation.requestedAt': FieldValue.serverTimestamp(),
        'cancellation.reason': 'Series cancelled by customer',
      });
      cancelledCount++;
    }
    if (cancelledCount > 0) {
      batch.update(_series.doc(recurringGroupId), {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': customerId,
      });
    }
    await batch.commit();
  }

  /// Confirm all deposit_submitted bookings in a recurring series.
  /// Idempotent: reads the series doc first and skips if already confirmed.
  Future<void> approveRecurringSeries(String recurringGroupId, String confirmedBy) async {
    final seriesSnap = await _series.doc(recurringGroupId).get();
    if (seriesSnap.exists) {
      final currentStatus = seriesSnap.data()?['status'] as String?;
      if (currentStatus == 'confirmed') {
        debugPrint('[approveRecurringSeries] already confirmed — skipping');
        return;
      }
    }

    final snap = await _bookings
        .where('ownerId', isEqualTo: confirmedBy)
        .where('recurringGroupId', isEqualTo: recurringGroupId)
        .where('status', isEqualTo: 'deposit_submitted')
        .get();
    if (snap.docs.isEmpty) return;

    // Sort by recurringWeek so week 1 is always first.
    final docs = snap.docs.toList()
      ..sort((a, b) =>
          ((a.data()['recurringWeek'] as int?) ?? 99)
              .compareTo((b.data()['recurringWeek'] as int?) ?? 99));

    final batch = _db.batch();
    // Confirm only the first week (smallest recurringWeek).
    // Remaining weeks go back to pending_deposit so the customer pays per week.
    final firstDoc = docs.first;
    batch.update(firstDoc.reference, {
      'status': 'confirmed',
      'paymentStatus': PaymentStatus.depositAccepted.key,
      'confirmedBy': confirmedBy,
      'confirmedAt': FieldValue.serverTimestamp(),
    });
    for (final doc in docs.skip(1)) {
      batch.update(doc.reference, {
        'status': 'pending_deposit',
        'paymentStatus': PaymentStatus.unpaid.key,
        // Clear the shared screenshot so the customer must upload per week.
        'depositPayment': FieldValue.delete(),
      });
    }
    // Update series doc: confirmed = 1, status = partially_confirmed.
    final totalOccurrences = seriesSnap.data()?['totalOccurrences'] as int? ?? docs.length;
    batch.set(
      _series.doc(recurringGroupId),
      {
        'status': totalOccurrences == 1 ? 'confirmed' : 'partially_confirmed',
        'confirmedCount': 1,
        'confirmedAt': FieldValue.serverTimestamp(),
        'confirmedBy': confirmedBy,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Reject all deposit_submitted bookings in a recurring series.
  /// Idempotent: no-op if already rejected/cancelled.
  Future<void> rejectRecurringSeries(String recurringGroupId, String rejectedBy) async {
    final seriesSnap = await _series.doc(recurringGroupId).get();
    if (seriesSnap.exists) {
      final currentStatus = seriesSnap.data()?['status'] as String?;
      if (currentStatus == 'cancelled' || currentStatus == 'rejected') {
        debugPrint('[rejectRecurringSeries] already rejected — skipping');
        return;
      }
    }

    final snap = await _bookings
        .where('ownerId', isEqualTo: rejectedBy)
        .where('recurringGroupId', isEqualTo: recurringGroupId)
        .where('status', isEqualTo: 'deposit_submitted')
        .get();
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'status': 'rejected',
        'paymentStatus': PaymentStatus.unpaid.key,
        'rejectedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(
      _series.doc(recurringGroupId),
      {'status': 'cancelled', 'rejectedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
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

  /// Real-time stream of taken hours for a court on a date, derived from
  /// slotLocks. Returns a Set<int> of booked hours. Updates instantly when
  /// any booking creates or releases a slot lock.
  Stream<Set<int>> bookedHoursStream(String courtId, DateTime date) {
    final dateStr =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final prefix = '${courtId}_${dateStr}_';
    // slotLock doc IDs: {courtId}_{yyyyMMdd}_{HH}
    // Query by courtId field + date field stored in each lock doc.
    return _slotLocks
        .where('courtId', isEqualTo: courtId)
        .where('date',
            isEqualTo: Timestamp.fromDate(
                DateTime(date.year, date.month, date.day)))
        .snapshots()
        .map((snap) {
      final hours = <int>{};
      for (final doc in snap.docs) {
        // Parse the hour from the document ID suffix.
        final id = doc.id;
        if (id.startsWith(prefix)) {
          final hStr = id.substring(prefix.length);
          final h = int.tryParse(hStr);
          if (h != null) hours.add(h);
        }
      }
      return hours;
    });
  }

  /// Booked slots for a court on a specific date (for slot grid).
  Future<List<BookingModel>> bookedSlots(
      String courtId, DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final snap = await _bookings
        .where('courtId', isEqualTo: courtId)
        .where('date', isEqualTo: Timestamp.fromDate(day))
        .where('status',
            whereIn: ['pending_deposit', 'deposit_submitted', 'confirmed', 'ongoing'])
        .get();
    return snap.docs
        .map((d) => BookingModel.fromMap({...d.data(), 'id': d.id}))
        .toList();
  }
}
