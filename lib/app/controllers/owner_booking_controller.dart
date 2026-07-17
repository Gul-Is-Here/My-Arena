import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/booking_model.dart';
import '../services/booking_service.dart';
import 'chat_controller.dart';

class OwnerBookingController extends GetxController {
  static OwnerBookingController get to => Get.find();

  final BookingService _service = BookingService();
  final ImagePicker _picker = ImagePicker();

  final RxList<BookingModel> bookings = <BookingModel>[].obs;
  final RxBool isLoading = true.obs;
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
    _sub = _service.ownerBookings(uid).listen((list) {
      bookings.assignAll(list);
      isLoading.value = false;
    }, onError: (e) {
      debugPrint('ownerBookings stream error: $e');
      isLoading.value = false;
      // One-off errors (e.g. index still building) shouldn't kill the tab.
      _retryTimer = Timer(const Duration(seconds: 8), () => _listen(_uid));
    });
  }

  Future<void> approve(String id) async {
    await _service.confirmBooking(id, _uid);
    final b = bookings.firstWhereOrNull((x) => x.id == id);
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
    await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
      'checkedIn': true,
      'checkedInAt': FieldValue.serverTimestamp(),
    });
    return null; // null = success
  }

  Future<void> addManualBooking(BookingModel booking) async {
    // Manual walk-ins are confirmed immediately — payment taken in person
    final ref = await _service.createBooking(
      booking.copyWith(ownerId: _uid),
    );
    await _service.confirmBooking(ref, _uid);
  }

  @override
  void onClose() {
    _retryTimer?.cancel();
    _authSub?.cancel();
    _sub?.cancel();
    super.onClose();
  }
}
