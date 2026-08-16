import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/arena_model.dart';
import '../services/arena_service.dart';

class ArenaFormController extends GetxController {
  final ArenaService _arenaService = ArenaService();

  /// When set by an admin creating an arena on behalf of an owner,
  /// this overrides the current user's uid as the arena's ownerId.
  String? ownerIdOverride;
  String? ownerNameOverride;
  String? adminCreatedFor; // invitationId — used for orphan cleanup if invite is revoked

  final RxInt currentStep = 0.obs;
  static const int totalSteps = 3;

  // Step 1 — basic info
  final nameCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();

  // Step 2 — images
  final RxList<XFile> images = <XFile>[].obs;
  final ImagePicker _picker = ImagePicker();

  // Step 3 — location
  final addressCtrl = TextEditingController();
  final Rx<LatLng?> pickedLatLng = Rx<LatLng?>(null);
  // Populated by reverse geocoding when owner pins a location.
  String _pickedCity        = '';
  String _pickedCountry     = '';
  String _pickedCountryCode = '';

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
    // Reverse-geocode in background — does not block the UI.
    _reverseGeocode(latLng);
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    try {
      final marks = await Geocoding().placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      if (marks.isNotEmpty) {
        final p = marks.first;
        _pickedCity        = (p.locality        ?? '').trim();
        _pickedCountry     = (p.country         ?? '').trim();
        _pickedCountryCode = (p.isoCountryCode  ?? '').trim();
      }
    } catch (_) {
      // Geocoding failure is non-fatal — city/country stay empty.
    }
  }

  Future<void> submit() async {
    if (!validateStep()) return;
    isSubmitting.value = true;
    try {
      final uid = ownerIdOverride ??
          FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) {
        _warn('You must be signed in to create an arena.');
        isSubmitting.value = false;
        return;
      }
      final location = pickedLatLng.value;

      final arena = ArenaModel(
        id: '',
        ownerId: uid,
        name: nameCtrl.text.trim(),
        description: descriptionCtrl.text.trim(),
        images: const [],
        location: ArenaLocation(
          address:        addressCtrl.text.trim(),
          city:           _pickedCity,
          country:        _pickedCountry,
          countryCode:    _pickedCountryCode,
          normalizedCity: _pickedCity.toLowerCase().trim(),
          lat:            location?.latitude  ?? 0,
          lng:            location?.longitude ?? 0,
        ),
        status: ArenaStatus.pending,
      );

      String arenaId;
      try {
        arenaId = await _arenaService.createArena(arena);
      } catch (e) {
        debugPrint('Arena create failed: $e');
        isSubmitting.value = false;
        _warn(e.toString().contains('permission-denied')
            ? 'Permission denied. Make sure your account has the owner role.'
            : 'Could not create arena: $e');
        return;
      }

      // Write admin-on-behalf-of metadata so revocation can find orphaned arenas.
      if (adminCreatedFor != null || ownerIdOverride != null) {
        final adminUid = FirebaseAuth.instance.currentUser?.uid;
        await _arenaService.updateArena(arenaId, {
          'adminCreatedFor': adminCreatedFor,
          'adminCreatedBy': ?adminUid,
        });
      }

      try {
        final files = images.toList();
        if (files.isNotEmpty) {
          final imageUrls =
              await _arenaService.uploadArenaImages(arenaId, files);
          await _arenaService.updateArena(arenaId, {'images': imageUrls});
        }
      } catch (e) {
        debugPrint('Image upload failed (arena created): $e');
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
      debugPrint('Arena submit failed: $e');
      _warn('Failed to submit: $e');
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

  void reset() {
    currentStep.value = 0;
    nameCtrl.clear();
    descriptionCtrl.clear();
    images.clear();
    addressCtrl.clear();
    pickedLatLng.value  = null;
    _pickedCity         = '';
    _pickedCountry      = '';
    _pickedCountryCode  = '';
    isSubmitting.value  = false;
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    descriptionCtrl.dispose();
    addressCtrl.dispose();
    super.onClose();
  }
}
