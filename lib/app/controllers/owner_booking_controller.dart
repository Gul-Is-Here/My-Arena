import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/booking_model.dart';
import '../services/booking_service.dart';
import 'auth_controller.dart';
import 'chat_controller.dart';

class OwnerBookingController extends GetxController {
  static OwnerBookingController get to => Get.find();

  final BookingService _service = BookingService();
  final ImagePicker _picker = ImagePicker();

  final RxList<BookingModel> bookings = <BookingModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  int _pageLimit = 200;
  final RxBool canLoadMore = false.obs;
  StreamSubscription? _sub;
  StreamSubscription? _authSub;
  Timer? _retryTimer;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

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
    // Re-subscribe whenever the signed-in user changes; the controller is
    // permanent, so a one-shot subscription would go stale across logins.
    _authSub = FirebaseAuth.instance
        .authStateChanges()
        .listen((user) => _listen(user?.uid));
    _listen(_uid);
  }

  void _listen(String? uid) {
    _retryTimer?.cancel();
    _sub?.cancel();
    _sub = null;
    if (uid == null || uid.isEmpty) {
      bookings.clear();
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    hasError.value = false;
    final currentUser = AuthController.to.currentUser.value;
    final Stream<List<BookingModel>> stream;
    if (currentUser?.isArenaStaff == true &&
        currentUser!.assignedArenas.isNotEmpty) {
      stream = _service.staffBookings(currentUser.assignedArenas,
          limit: _pageLimit);
    } else {
      stream = _service.ownerBookings(uid, limit: _pageLimit);
    }
    _sub = stream.listen((list) {
      bookings.assignAll(list);
      canLoadMore.value = list.length >= _pageLimit;
      isLoading.value = false;
      hasError.value = false;
      _autoCompleteExpired(list);
    }, onError: (e) {
      debugPrint('ownerBookings stream error: $e');
      isLoading.value = false;
      hasError.value = true;
      _retryTimer = Timer(const Duration(seconds: 8), () => _listen(_uid));
    });
  }

  void retry() => _listen(_uid);

  void loadMore() {
    _pageLimit += 100;
    _listen(_uid);
  }

  // Fallback for the scheduled Cloud Function: confirmed bookings whose end
  // time has passed get completed from the owner's client too. The status
  // change fires the onBookingUpdated function, which pushes the
  // "Session Complete" notification to the booking's customer.
  final Set<String> _autoCompleting = {};

  void _autoCompleteExpired(List<BookingModel> list) {
    final now = DateTime.now();
    for (final b in list) {
      if (b.status == BookingStatus.confirmed &&
          b.endDateTime.isBefore(now) &&
          !_autoCompleting.contains(b.id)) {
        _autoCompleting.add(b.id);
        _service.autoComplete(b.id, noShow: !b.checkedIn).catchError((e) {
          _autoCompleting.remove(b.id);
          debugPrint('auto-complete failed for ${b.id}: $e');
        });
      }
    }
  }

  /// [booking] lets callers outside this controller's stream (e.g. the chat
  /// banner) supply the model directly, so the confirmation chat message is
  /// sent even before the owner's bookings stream has loaded.
  Future<void> approve(String id, {BookingModel? booking}) async {
    await _service.confirmBooking(id, _uid);
    final b = booking ?? bookings.firstWhereOrNull((x) => x.id == id);
    if (b != null) {
      // Tell the customer in the booking chat as well as via push.
      if (!Get.isRegistered<ChatController>()) {
        Get.put(ChatController(), permanent: true);
      }
      try {
        await ChatController.to.sendBookingConfirmedMessage(b);
      } catch (e) {
        debugPrint('confirm chat message failed: $e');
      }
    }
  }

  Future<void> reject(String id) async {
    await _service.rejectBooking(id);
  }

  Future<void> sendRefund(String id) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    await _service.submitRefund(id, File(picked.path));
  }

  /// Called by the QR scanner when the owner scans a customer's booking QR.
  /// Validates the booking (must be confirmed and for today or future) then
  /// marks it checked-in in Firestore.
  Future<String?> checkIn(String bookingId) async {
    final b = bookings.firstWhereOrNull((x) => x.id == bookingId);
    if (b == null) return 'Booking not found';
    if (b.checkedIn) return 'Already checked in';
    if (b.status != BookingStatus.confirmed) {
      return 'Booking is not confirmed (status: ${b.status.label})';
    }
    final now = DateTime.now();
    final start = b.startDateTime;
    final end = b.endDateTime;
    if (now.isAfter(end)) return 'Booking slot has already ended';
    if (start.difference(now).inHours > 2) {
      return 'Too early — check-in opens 2 hours before the slot';
    }
    await _service.checkIn(bookingId);
    return null; // null = success
  }

  Future<void> markNoShow(String bookingId) => _service.markNoShow(bookingId);

  Future<void> approveReschedule(String bookingId) async {
    final b = bookings.firstWhereOrNull((x) => x.id == bookingId);
    final req = b?.rescheduleRequest;
    if (req == null) return;
    await _service.approveReschedule(bookingId, req);
  }

  Future<void> rejectReschedule(String bookingId) =>
      _service.rejectReschedule(bookingId);

  Future<void> addManualBooking(BookingModel booking) async {
    await _service.createManualBooking(
      booking.copyWith(ownerId: _uid),
    );
  }

  @override
  void onClose() {
    _retryTimer?.cancel();
    _authSub?.cancel();
    _sub?.cancel();
    super.onClose();
  }
}
