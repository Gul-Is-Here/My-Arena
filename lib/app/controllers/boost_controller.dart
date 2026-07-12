import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../data/dummy_data.dart';
import '../data/models/boost_request_model.dart';

/// Boost / Feature arena + event promotion requests (JazzCash manual flow).
class BoostController extends GetxController {
  static BoostController get to => Get.find();

  final RxList<BoostRequestModel> requests =
      RxList<BoostRequestModel>(DummyData.boostRequests);

  final Rx<BoostDuration> selectedDuration = BoostDuration.oneWeek.obs;
  final Rxn<XFile> screenshot = Rxn<XFile>();
  final RxBool isSubmitting = false.obs;

  // Event promotion extras
  final eventNameCtrl = TextEditingController();
  final eventDescriptionCtrl = TextEditingController();
  final eventAttendeesCtrl = TextEditingController();
  final Rxn<DateTime> eventDate = Rxn<DateTime>();

  final ImagePicker _picker = ImagePicker();

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
    await Future.delayed(const Duration(milliseconds: 900)); // simulate save

    requests.insert(
      0,
      BoostRequestModel(
        id: 'boost-${DateTime.now().millisecondsSinceEpoch}',
        arenaId: arenaId,
        arenaName: arenaName,
        type: type,
        duration: selectedDuration.value,
        price: selectedDuration.value.price,
        paymentScreenshot: screenshot.value!.path,
        accountUsed: DummyData.jazzCashNumber,
        eventDetails: type == BoostType.event
            ? {
                'name': eventNameCtrl.text.trim(),
                'description': eventDescriptionCtrl.text.trim(),
                'date': eventDate.value?.toIso8601String(),
                'expectedAttendees': eventAttendeesCtrl.text.trim(),
              }
            : null,
        createdAt: DateTime.now(),
      ),
    );

    isSubmitting.value = false;
    _resetForm();
    Get.back();
    Get.snackbar(
      'Request submitted',
      'Your ${type == BoostType.boost ? 'boost' : 'event promotion'} request is pending admin review',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
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
    eventNameCtrl.dispose();
    eventDescriptionCtrl.dispose();
    eventAttendeesCtrl.dispose();
    super.onClose();
  }
}
