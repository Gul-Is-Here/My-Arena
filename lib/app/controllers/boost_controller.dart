import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/boost_request_model.dart';
import '../services/boost_service.dart';

class BoostController extends GetxController {
  static BoostController get to => Get.find();

  final BoostService _boostService = BoostService();

  final RxList<BoostRequestModel> requests = <BoostRequestModel>[].obs;
  final Rx<BoostDuration> selectedDuration = BoostDuration.oneWeek.obs;
  final Rxn<XFile> screenshot = Rxn<XFile>();
  final RxBool isSubmitting = false.obs;

  final RxString jazzCashNumber = '0300-0000000'.obs;

  // Pricing from Firestore settings/boostPricing
  final RxMap<String, double> pricing = <String, double>{
    '1_week': 1500,
    '2_week': 2500,
    '1_month': 4000,
  }.obs;

  // Event promotion extras
  final eventNameCtrl = TextEditingController();
  final eventDescriptionCtrl = TextEditingController();
  final eventAttendeesCtrl = TextEditingController();
  final Rxn<DateTime> eventDate = Rxn<DateTime>();

  final ImagePicker _picker = ImagePicker();
  StreamSubscription? _requestsSub;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void onInit() {
    super.onInit();
    _loadPricing();
    _listenRequests();
  }

  Future<void> _loadPricing() async {
    try {
      final p = await _boostService.fetchPricing();
      pricing.assignAll(p);
    } catch (_) {}
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('booking')
          .get();
      jazzCashNumber.value =
          doc.data()?['jazzCashNumber'] ?? jazzCashNumber.value;
    } catch (_) {}
  }

  void _listenRequests() {
    if (_uid.isEmpty) return;
    _requestsSub = _boostService.ownerRequests(_uid).listen((list) {
      requests.assignAll(list);
    });
  }

  double get currentPrice {
    switch (selectedDuration.value) {
      case BoostDuration.oneWeek:
        return pricing['1_week'] ?? 1500;
      case BoostDuration.twoWeeks:
        return pricing['2_week'] ?? 2500;
      case BoostDuration.oneMonth:
        return pricing['1_month'] ?? 4000;
    }
  }

  Future<void> pickScreenshot() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) screenshot.value = picked;
  }

  Future<void> submit({
    required String arenaId,
    required String arenaName,
    required BoostType type,
  }) async {
    if (screenshot.value == null) {
      Get.snackbar(
        'Payment proof required',
        'Upload your JazzCash payment screenshot',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }
    if (type == BoostType.event && eventNameCtrl.text.trim().isEmpty) {
      Get.snackbar(
        'Event name required',
        'Fill in the event details before submitting',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    isSubmitting.value = true;
    try {
      final req = BoostRequestModel(
        id: '',
        arenaId: arenaId,
        arenaName: arenaName,
        ownerId: _uid,
        type: type,
        duration: selectedDuration.value,
        price: currentPrice,
        eventDetails: type == BoostType.event
            ? {
                'name': eventNameCtrl.text.trim(),
                'description': eventDescriptionCtrl.text.trim(),
                'date': eventDate.value?.toIso8601String(),
                'expectedAttendees': eventAttendeesCtrl.text.trim(),
              }
            : null,
        createdAt: DateTime.now(),
      );
      await _boostService.createRequest(req, File(screenshot.value!.path));
      isSubmitting.value = false;
      _resetForm();
      Get.back();
      Get.snackbar(
        'Request submitted',
        'Your ${type == BoostType.boost ? 'boost' : 'event promotion'} request is pending admin review',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      isSubmitting.value = false;
      Get.snackbar(
        'Submission failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  void _resetForm() {
    selectedDuration.value = BoostDuration.oneWeek;
    screenshot.value = null;
    eventNameCtrl.clear();
    eventDescriptionCtrl.clear();
    eventAttendeesCtrl.clear();
    eventDate.value = null;
  }

  @override
  void onClose() {
    _requestsSub?.cancel();
    eventNameCtrl.dispose();
    eventDescriptionCtrl.dispose();
    eventAttendeesCtrl.dispose();
    super.onClose();
  }
}
