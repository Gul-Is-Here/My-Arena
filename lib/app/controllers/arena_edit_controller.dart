import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/arena_model.dart';
import '../services/arena_service.dart';

/// Edit an existing arena's information (name, description, photos, location).
/// Court management is handled separately from the Arena Details screen.
class ArenaEditController extends GetxController {
  ArenaEditController({required this.arenaId});

  final String arenaId;
  final ArenaService _arenaService = ArenaService();

  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;
  final RxBool loadFailed = false.obs;

  final nameCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();

  final RxList<String> existingImages = <String>[].obs;
  final RxList<XFile> newImages = <XFile>[].obs;
  final ImagePicker _picker = ImagePicker();

  final addressCtrl = TextEditingController();
  final Rx<LatLng?> pickedLatLng = Rx<LatLng?>(null);

  ArenaModel? _arena;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    try {
      final arena = await _arenaService.fetchArena(arenaId);
      if (arena == null) {
        loadFailed.value = true;
        return;
      }
      _arena = arena;
      nameCtrl.text = arena.name;
      descriptionCtrl.text = arena.description;
      addressCtrl.text = arena.location.address;
      if (arena.location.lat != 0 || arena.location.lng != 0) {
        pickedLatLng.value = LatLng(arena.location.lat, arena.location.lng);
      }
      existingImages.assignAll(arena.images);
    } catch (_) {
      loadFailed.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 80);
      if (picked.isNotEmpty) newImages.addAll(picked);
    } catch (_) {
      _warn('Could not load image — try a different photo');
    }
  }

  void removeExistingImage(int index) => existingImages.removeAt(index);
  void removeNewImage(int index) => newImages.removeAt(index);
  int get totalImages => existingImages.length + newImages.length;

  void setLocation(LatLng latLng, {String? address}) {
    pickedLatLng.value = latLng;
    if (address != null && address.isNotEmpty) addressCtrl.text = address;
  }

  bool _validate() {
    if (nameCtrl.text.trim().length < 3) {
      _warn('Arena name must be at least 3 characters');
      return false;
    }
    if (descriptionCtrl.text.trim().length < 10) {
      _warn('Add a short description (min 10 characters)');
      return false;
    }
    if (totalImages == 0) {
      _warn('Keep at least one arena photo');
      return false;
    }
    if (addressCtrl.text.trim().isEmpty) {
      _warn('Enter the arena address');
      return false;
    }
    return true;
  }

  Future<void> save() async {
    if (isSaving.value || !_validate()) return;
    isSaving.value = true;
    try {
      final files = newImages.toList();
      final uploadedUrls = files.isEmpty
          ? <String>[]
          : await _arenaService.uploadArenaImages(arenaId, files);

      final location = pickedLatLng.value;
      await _arenaService.updateArena(arenaId, {
        'name': nameCtrl.text.trim(),
        'description': descriptionCtrl.text.trim(),
        'images': [...existingImages, ...uploadedUrls],
        'location': {
          'address': addressCtrl.text.trim(),
          'lat': location?.latitude ?? _arena?.location.lat ?? 0,
          'lng': location?.longitude ?? _arena?.location.lng ?? 0,
        },
      });

      isSaving.value = false;
      Get.back();
      Get.snackbar(
        'Arena updated',
        '${nameCtrl.text.trim()} has been saved',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      isSaving.value = false;
      debugPrint('Arena save failed: $e');
      final msg = e.toString();
      if (msg.contains('permission-denied')) {
        _warn('You don\'t have permission to update this arena. '
            'Make sure you\'re signed in as the arena owner.');
      } else if (msg.contains('not-found')) {
        _warn('Arena not found. It may have been deleted.');
      } else {
        _warn('Failed to save. Please check your connection and try again.');
      }
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
