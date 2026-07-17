import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/arena_model.dart';
import '../data/models/court_model.dart';
import '../services/arena_service.dart';

/// Edit an existing arena: every field (basic info, photos, location,
/// courts) is loaded from Firestore and written back on save.
class ArenaEditController extends GetxController {
  ArenaEditController({required this.arenaId});

  final String arenaId;
  final ArenaService _arenaService = ArenaService();

  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;
  final RxBool loadFailed = false.obs;

  // Basic info
  final nameCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();

  // Images — existing Storage URLs plus newly picked local files
  final RxList<String> existingImages = <String>[].obs;
  final RxList<XFile> newImages = <XFile>[].obs;
  final ImagePicker _picker = ImagePicker();

  // Location
  final addressCtrl = TextEditingController();
  final Rx<LatLng?> pickedLatLng = Rx<LatLng?>(null);

  // Courts — edited locally, synced to the subcollection on save
  final RxList<CourtModel> courts = <CourtModel>[].obs;
  final Set<String> _originalCourtIds = {};

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

      final allCourts = await _arenaService.fetchAllCourts(arenaId);
      courts.assignAll(allCourts);
      _originalCourtIds
        ..clear()
        ..addAll(allCourts.map((c) => c.id));
    } catch (_) {
      loadFailed.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  // ── Images ────────────────────────────────────────────────────────────

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

  // ── Location ──────────────────────────────────────────────────────────

  void setLocation(LatLng latLng) => pickedLatLng.value = latLng;

  // ── Courts ────────────────────────────────────────────────────────────

  void upsertCourt(CourtModel court) {
    final index = courts.indexWhere((c) => c.id == court.id);
    if (index == -1) {
      courts.add(court);
    } else {
      courts[index] = court;
      courts.refresh();
    }
  }

  void removeCourt(int index) => courts.removeAt(index);

  // ── Save ──────────────────────────────────────────────────────────────

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
    if (courts.isEmpty) {
      _warn('Keep at least one court');
      return false;
    }
    return true;
  }

  Future<void> save() async {
    if (isSaving.value || !_validate()) return;
    isSaving.value = true;
    try {
      // 1. Upload any newly added photos
      final files = newImages.map((x) => File(x.path)).toList();
      final uploadedUrls = files.isEmpty
          ? <String>[]
          : await _arenaService.uploadArenaImages(arenaId, files);

      // 2. Update the arena document
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

      // 3. Sync courts: update kept ones, add new ones, delete removed ones
      final keptIds = <String>{};
      for (final court in courts) {
        if (_originalCourtIds.contains(court.id)) {
          keptIds.add(court.id);
          await _arenaService.updateCourt(arenaId, court.id, court.toMap());
        } else {
          await _arenaService.addCourt(arenaId, court);
        }
      }
      for (final id in _originalCourtIds.difference(keptIds)) {
        await _arenaService.deleteCourt(arenaId, id);
      }

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
      _warn('Failed to save: ${e.toString()}');
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
