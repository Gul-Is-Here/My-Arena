import 'package:get/get.dart';

import '../data/models/booking_model.dart';

/// Owner/staff booking management — approvals, walk-ins, refunds.
/// Separate list from the customer's BookingController so dummy data
/// for the two roles doesn't mix; both merge into one Firestore
/// collection in the backend phase.
class OwnerBookingController extends GetxController {
  static OwnerBookingController get to => Get.find();

  final RxList<BookingModel> bookings = <BookingModel>[].obs;

  List<BookingModel> get pendingApproval => bookings
      .where((b) => b.status == BookingStatus.depositSubmitted)
      .toList()
    ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

  List<BookingModel> get all => bookings.toList()
    ..sort((a, b) => b.startDateTime.compareTo(a.startDateTime));

  List<BookingModel> get refunds => bookings
      .where((b) =>
          b.status == BookingStatus.refundPending ||
          b.status == BookingStatus.refundSent)
      .toList()
    ..sort((a, b) => b.startDateTime.compareTo(a.startDateTime));

  @override
  void onInit() {
    super.onInit();
    _seed();
  }

  void _setStatus(String id, BookingStatus status) {
    final i = bookings.indexWhere((b) => b.id == id);
    if (i == -1) return;
    bookings[i] = bookings[i].copyWith(status: status);
  }

  void approve(String id) => _setStatus(id, BookingStatus.confirmed);
  void reject(String id) => _setStatus(id, BookingStatus.rejected);

  /// Refund screenshot "uploaded" → refund marked sent; customer
  /// confirms receipt on their side in the backend phase.
  void sendRefund(String id) => _setStatus(id, BookingStatus.refundSent);

  /// Walk-in bookings are confirmed immediately — payment is in hand.
  void addManualBooking(BookingModel booking) {
    bookings.add(booking.copyWith(status: BookingStatus.confirmed));
  }

  void _seed() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bookings.addAll([
      BookingModel(
        id: 'ob-1',
        arenaId: 'arena-1',
        arenaName: 'Champions Arena',
        courtId: 'court-1',
        courtName: 'Padel Court A',
        customerName: 'Ali Raza',
        date: today.add(const Duration(days: 1)),
        startHour: 19,
        totalHours: 2,
        pricePerHour: 3000,
        status: BookingStatus.depositSubmitted,
        depositScreenshot: 'mock-screenshot.png',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      BookingModel(
        id: 'ob-2',
        arenaId: 'arena-1',
        arenaName: 'Champions Arena',
        courtId: 'court-2',
        courtName: 'Football Ground',
        customerName: 'Hamza Sheikh',
        date: today.add(const Duration(days: 3)),
        startHour: 21,
        totalHours: 1,
        pricePerHour: 5000,
        status: BookingStatus.depositSubmitted,
        depositScreenshot: 'mock-screenshot.png',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      BookingModel(
        id: 'ob-3',
        arenaId: 'arena-1',
        arenaName: 'Champions Arena',
        courtId: 'court-1',
        courtName: 'Padel Court A',
        customerName: 'Usman Khalid',
        date: today.add(const Duration(days: 2)),
        startHour: 18,
        totalHours: 2,
        pricePerHour: 3000,
        status: BookingStatus.confirmed,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      BookingModel(
        id: 'ob-4',
        arenaId: 'arena-1',
        arenaName: 'Champions Arena',
        courtId: 'court-2',
        courtName: 'Football Ground',
        customerName: 'Bilal Ahmed',
        date: today.subtract(const Duration(days: 2)),
        startHour: 20,
        totalHours: 2,
        pricePerHour: 5000,
        status: BookingStatus.completed,
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      BookingModel(
        id: 'ob-5',
        arenaId: 'arena-1',
        arenaName: 'Champions Arena',
        courtId: 'court-1',
        courtName: 'Padel Court A',
        customerName: 'Sara Malik',
        date: today.add(const Duration(days: 4)),
        startHour: 17,
        totalHours: 1,
        pricePerHour: 3000,
        status: BookingStatus.refundPending,
        cancellation: CancellationInfo(
          requestedAt: now.subtract(const Duration(hours: 3)),
          refundAmount: 720,
          bankName: 'JazzCash',
          accountNumber: '03001112233',
        ),
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ]);
  }
}
