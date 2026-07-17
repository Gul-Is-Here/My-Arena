import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/arena_model.dart';
import '../data/models/court_model.dart';
import '../services/arena_service.dart';

class ArenaFormController extends GetxController {
  final ArenaService _arenaService = ArenaService();

  final RxInt currentStep = 0.obs;
  static const int totalSteps = 5;

  // Step 1 — basic info
  final nameCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();

  // Step 2 — images
  final RxList<XFile> images = <XFile>[].obs;
  final ImagePicker _picker = ImagePicker();

  // Step 3 — location
  final addressCtrl = TextEditingController();
  final Rx<LatLng?> pickedLatLng = Rx<LatLng?>(null);

  // Step 4 — courts
  final RxList<CourtModel> courts = <CourtModel>[].obs;

  final RxBool isSubmitting = false.obs;

  bool validateStep() {
    switch (currentStep.value) {
      case 0:
        if (nameCtrl.text.trim().length < 3) {
          _warn('Arena name must be at least 3 characters');
          return false;
        }
        if (descriptionCtrl.text.trim().length < 10) {
          _warn('Add a short description (min 10 characters)');
          return false;
        }
        return true;
      case 1:
        if (images.isEmpty) {
          _warn('Add at least one arena photo');
          return false;
        }
        return true;
      case 2:
        if (addressCtrl.text.trim().isEmpty) {
          _warn('Enter the arena address');
          return false;
        }
        return true;
      case 3:
        if (courts.isEmpty) {
          _warn('Add at least one court');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void nextStep() {
    if (!validateStep()) return;
    if (currentStep.value < totalSteps - 1) currentStep.value++;
  }

  void previousStep() {
    if (currentStep.value > 0) currentStep.value--;
  }

  Future<void> pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 80);
      if (picked.isNotEmpty) images.addAll(picked);
    } catch (e) {
      Get.snackbar(
        'Could not load image',
        'Please try selecting a different photo.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  void removeImage(int index) => images.removeAt(index);

  void setLocation(LatLng latLng, String address) {
    pickedLatLng.value = latLng;
    addressCtrl.text = address;
  }

  void addCourt(CourtModel court) => courts.add(court);

  void removeCourt(int index) => courts.removeAt(index);

  Future<void> submit() async {
    isSubmitting.value = true;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final location = pickedLatLng.value;

      // 1. Create arena doc first to get its ID
      final arena = ArenaModel(
        id: '',
        ownerId: uid,
        name: nameCtrl.text.trim(),
        description: descriptionCtrl.text.trim(),
        images: const [],
        location: ArenaLocation(
          address: addressCtrl.text.trim(),
          lat: location?.latitude ?? 0,
          lng: location?.longitude ?? 0,
        ),
        status: ArenaStatus.pending,
      );
      final arenaId = await _arenaService.createArena(arena);

      // 2. Upload images then update arena doc with URLs
      final files = images.map((x) => File(x.path)).toList();
      final imageUrls = await _arenaService.uploadArenaImages(arenaId, files);
      await _arenaService.updateArena(arenaId, {'images': imageUrls});

      // 3. Save courts as subcollection
      for (final court in courts) {
        await _arenaService.addCourt(arenaId, court);
      }

      isSubmitting.value = false;
      Get.back();
      Get.snackbar(
        'Submitted for review',
        '${nameCtrl.text.trim()} is pending admin approval',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      isSubmitting.value = false;
      _warn('Failed to submit: ${e.toString()}');
    }
  }

  void _warn(String message) {
    Get.snackbar(
      'Hold on',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    descriptionCtrl.dispose();
    addressCtrl.dispose();
    super.onClose();
  }
}
