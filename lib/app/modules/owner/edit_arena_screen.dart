import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/arena_edit_controller.dart';
import '../../data/models/court_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/arena_image.dart';
import '../../widgets/location_picker.dart';
import 'add_court_bottom_sheet.dart';

/// Full arena editor for owners: basic info, photos, location, and courts
/// in one scrollable form. Changes are written back to Firestore on save.
class EditArenaScreen extends StatelessWidget {
  const EditArenaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String arenaId = Get.arguments as String;
    final c = Get.put(ArenaEditController(arenaId: arenaId), tag: arenaId);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Arena')),
      body: SafeArea(
        child: Obx(() {
          if (c.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (c.loadFailed.value) {
            return Center(
              child: Text(
                'Could not load arena details',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textGrey),
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionTitle('Basic Info'),
                    AppTextField(
                      label: 'Arena Name',
                      hint: 'e.g. Champions Arena',
                      controller: c.nameCtrl,
                      prefixIcon: Icons.stadium_outlined,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Description',
                      hint: 'Tell customers what makes your arena great…',
                      controller: c.descriptionCtrl,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 28),

                    _sectionTitle('Photos'),
                    Text(
                      'The first photo becomes the cover.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 12),
                    _photosGrid(c),
                    const SizedBox(height: 28),

                    _sectionTitle('Location'),
                    _locationCard(c),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Address',
                      hint: 'Street, area, city',
                      controller: c.addressCtrl,
                      prefixIcon: Icons.location_on_outlined,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 28),

                    _sectionTitle('Courts'),
                    AppButton(
                      label: 'Add Court',
                      icon: Icons.add,
                      outlined: true,
                      onPressed: () => AddCourtBottomSheet.show(
                        context,
                        onAdd: c.upsertCourt,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Obx(
                      () => Column(
                        children: List.generate(
                          c.courts.length,
                          (i) => _courtTile(context, c, i),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Obx(
                  () => AppButton(
                    label: 'Save Changes',
                    isLoading: c.isSaving.value,
                    onPressed: c.save,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title, style: AppTextStyles.titleLarge),
      );

  Widget _photosGrid(ArenaEditController c) {
    return Obx(
      () => GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          GestureDetector(
            onTap: c.pickImages,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
                  SizedBox(height: 6),
                  Text('Add', style: TextStyle(color: AppColors.primary)),
                ],
              ),
            ),
          ),
          ...List.generate(
            c.existingImages.length,
            (i) => _photoThumb(
              path: c.existingImages[i],
              onRemove: () => c.removeExistingImage(i),
            ),
          ),
          ...List.generate(
            c.newImages.length,
            (i) => _photoThumb(
              path: c.newImages[i].path,
              onRemove: () => c.removeNewImage(i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoThumb({required String path, required VoidCallback onRemove}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ArenaImage(path: path),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _locationCard(ArenaEditController c) {
    return Obx(() {
      final latLng = c.pickedLatLng.value;
      return GestureDetector(
        onTap: () async {
          final result = await Navigator.push<LocationResult>(
            Get.context!,
            MaterialPageRoute(
              builder: (_) => LocationPicker(initial: latLng),
              fullscreenDialog: true,
            ),
          );
          if (result != null) c.setLocation(result.latLng);
        },
        child: AppCard(
          padding: EdgeInsets.zero,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryDark.withValues(alpha: 0.3),
                  AppColors.primary.withValues(alpha: 0.15),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  latLng != null ? Icons.location_on : Icons.map_outlined,
                  size: 44,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  latLng != null
                      ? '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}'
                      : 'Tap to pick location on map',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textGrey),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _courtTile(BuildContext context, ArenaEditController c, int index) {
    final court = c.courts[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_courtIcon(court.type), color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(court.name, style: AppTextStyles.titleMedium),
                  Text(
                    '${court.type.label} · ${court.capacity} players · '
                    '${court.startTime}–${court.endTime}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textGrey),
                  ),
                  Text(
                    'PKR ${court.pricePerHour.toStringAsFixed(0)}/hr',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 20, color: AppColors.primary),
              onPressed: () => AddCourtBottomSheet.show(
                context,
                initial: court,
                onAdd: c.upsertCourt,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: AppColors.error),
              onPressed: () => _confirmDeleteCourt(c, index, court.name),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCourt(ArenaEditController c, int index, String name) {
    Get.dialog(
      AlertDialog(
        title: const Text('Remove court?'),
        content: Text(
            '"$name" will be permanently removed when you save changes.'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              c.removeCourt(index);
            },
            child:
                const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  IconData _courtIcon(CourtType type) {
    switch (type) {
      case CourtType.football:
        return Icons.sports_soccer;
      case CourtType.padel:
        return Icons.sports_tennis;
      case CourtType.indoor:
        return Icons.home_work_outlined;
      case CourtType.cricket:
        return Icons.sports_cricket;
      case CourtType.other:
        return Icons.sports;
    }
  }
}
