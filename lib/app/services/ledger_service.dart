import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/models/booking_model.dart';
import '../data/models/pos_transaction_model.dart';

class LedgerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _txns =>
      _db.collection('posTransactions');
  CollectionReference<Map<String, dynamic>> get _bookings =>
      _db.collection('bookings');

  /// Idempotency-safe ledger write.
  /// If [txn.idempotencyKey] is set and a record with that key already exists,
  /// returns the existing document id without writing a duplicate.
  Future<String> record(PosTransactionModel txn) async {
    if (txn.idempotencyKey != null) {
      final existing = await _txns
          .where('idempotencyKey', isEqualTo: txn.idempotencyKey)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return existing.docs.first.id;
    }
    final ref = _txns.doc();
    await ref.set({...txn.toMap(), 'id': ref.id});
    return ref.id;
  }

  /// Builds the ledger entry that represents an online booking being confirmed.
  /// Caller is responsible for dedup via idempotencyKey.
  PosTransactionModel entryForConfirmedBooking(
    BookingModel booking,
    String confirmedById,
    String confirmedByName, {
    String confirmedByRole = 'owner',
    String? shiftId,
  }) {
    final depositPaid = booking.depositAmount;
    final remaining = (booking.totalAmount - depositPaid).clamp(0.0, double.infinity);
    return PosTransactionModel(
      id: '',
      arenaId: booking.arenaId,
      arenaName: booking.arenaName,
      bookingId: booking.id,
      courtId: booking.courtId,
      courtName: booking.courtName,
      customerId: booking.customerId.isEmpty ? null : booking.customerId,
      customerName: booking.customerName,
      type: PosTransactionType.booking,
      source: LedgerSource.online,
      paymentMethod: PosPaymentMethod.other, // online deposit — method unknown at confirm time
      totalAmount: booking.totalAmount,
      amountPaid: depositPaid,
      remainingAmount: remaining,
      discount: 0,
      processedById: confirmedById,
      processedByName: confirmedByName,
      processedByRole: confirmedByRole,
      createdAt: DateTime.now(),
      shiftId: shiftId,
      idempotencyKey: '${booking.id}_confirmed',
      notes: 'Online booking confirmed',
    );
  }

  /// Collects remaining balance from an existing online booking at the counter.
  /// Atomically: writes a ledger entry + increments booking.amountPaid.
  Future<void> collectBalance({
    required BookingModel booking,
    required double amount,
    required PosPaymentMethod method,
    String? refNo,
    String? shiftId,
    String? notes,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';
    // Unique key per payment so multiple partial collections are all recorded.
    final ikey = '${booking.id}_balance_${DateTime.now().millisecondsSinceEpoch}';
    final newRemaining =
        (booking.remainingAmount - amount).clamp(0.0, double.infinity);

    final txn = PosTransactionModel(
      id: '',
      arenaId: booking.arenaId,
      arenaName: booking.arenaName,
      bookingId: booking.id,
      courtId: booking.courtId,
      courtName: booking.courtName,
      customerId: booking.customerId.isEmpty ? null : booking.customerId,
      customerName: booking.customerName,
      type: PosTransactionType.checkout,
      source: LedgerSource.pos, // collected at the physical counter, not online
      paymentMethod: method,
      totalAmount: booking.totalAmount,
      amountPaid: amount,
      remainingAmount: newRemaining,
      discount: 0,
      refNo: refNo,
      processedById: uid,
      processedByName: '',
      processedByRole: 'owner',
      createdAt: DateTime.now(),
      shiftId: shiftId,
      idempotencyKey: ikey,
      notes: notes ?? 'Balance collected at counter',
    );

    final batch = _db.batch();
    final ledgerRef = _txns.doc();
    batch.set(ledgerRef, {...txn.toMap(), 'id': ledgerRef.id});
    batch.update(_bookings.doc(booking.id), {
      'amountPaid': FieldValue.increment(amount),
      'remainingAmount': FieldValue.increment(-amount),
    });
    await batch.commit();
  }
}
