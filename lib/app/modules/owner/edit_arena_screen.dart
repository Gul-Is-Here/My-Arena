import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/arena_edit_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/arena_image.dart';
import '../../widgets/location_picker.dart';

/// Arena editor for owners: basic info, photos, and location.
/// Court management is handled from the Arena Details screen.
class EditArenaScreen extends StatelessWidget {
  const EditArenaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? arenaId = Get.arguments as String?;
    if (arenaId == null) {
      return const Scaffold(body: Center(child: Text('No arena selected')));
    }
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
                      'The first photo becomes the cover. All courts under this arena share these images.',
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
          if (result != null) {
            c.setLocation(result.latLng, address: result.address);
          }
        },
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
                    ? (c.addressCtrl.text.isNotEmpty
                        ? c.addressCtrl.text
                        : 'Location selected — tap to change')
                    : 'Tap to pick location on map',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textGrey),
              ),
            ],
          ),
        ),
      );
    });
  }
}
