import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/arena_model.dart';
import '../data/models/court_model.dart';
import 'owner_controller.dart';

/// Multi-step Add Arena form state (5 steps per scope.md).
class ArenaFormController extends GetxController {
  final RxInt currentStep = 0.obs;
  static const int totalSteps = 5;

  // Step 1 — basic info
  final nameCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();

  // Step 2 — images
  final RxList<XFile> images = <XFile>[].obs;
  final ImagePicker _picker = ImagePicker();

  // Step 3 — location (map picker stubbed until google_maps is wired)
  final addressCtrl = TextEditingController();
  final RxBool locationPicked = false.obs;

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
          _warn('Pick the arena location');
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
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) images.addAll(picked);
  }

  void removeImage(int index) => images.removeAt(index);

  void addCourt(CourtModel court) => courts.add(court);

  void removeCourt(int index) => courts.removeAt(index);

  Future<void> submit() async {
    isSubmitting.value = true;
    await Future.delayed(const Duration(milliseconds: 900)); // simulate save
    final arena = ArenaModel(
      id: 'arena-${DateTime.now().millisecondsSinceEpoch}',
      ownerId: 'mock-login',
      name: nameCtrl.text.trim(),
      description: descriptionCtrl.text.trim(),
      images: images.map((x) => x.path).toList(),
      location: ArenaLocation(address: addressCtrl.text.trim()),
      status: ArenaStatus.pending,
      courts: courts.toList(),
      distanceKm: 0.5,
    );
    OwnerController.to.addArena(arena);
    isSubmitting.value = false;
    Get.back(); // close form
    Get.snackbar(
      'Submitted for review',
      '${arena.name} is pending admin approval',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
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
