import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/arena_form_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/arena_image.dart';
import '../../widgets/location_picker.dart';

/// Multi-step Add Arena flow:
/// Basic Info → Images → Location & Submit.
///
/// When [ownerIdOverride] is provided (admin creating on behalf of an owner),
/// the arena is attributed to that owner instead of the signed-in user.
class AddArenaScreen extends StatefulWidget {
  final String? ownerIdOverride;
  final String? ownerNameOverride;
  final String? adminCreatedFor;

  const AddArenaScreen({
    super.key,
    this.ownerIdOverride,
    this.ownerNameOverride,
    this.adminCreatedFor,
  });

  @override
  State<AddArenaScreen> createState() => _AddArenaScreenState();
}

class _AddArenaScreenState extends State<AddArenaScreen> {
  late final ArenaFormController _c;

  @override
  void initState() {
    super.initState();
    // Put once and reset once — never in build() which runs on every rebuild.
    _c = Get.put(ArenaFormController());
    _c.reset();
    // Set admin overrides AFTER reset so they aren't cleared.
    _c.ownerIdOverride = widget.ownerIdOverride;
    _c.ownerNameOverride = widget.ownerNameOverride;
    _c.adminCreatedFor = widget.adminCreatedFor;
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    const stepTitles = [
      'Basic Info',
      'Photos',
      'Location',
    ];

    return Scaffold(
      appBar: AppBar(
        leading: Obx(() => c.currentStep.value > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: c.previousStep,
              )
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Get.back(),
              )),
        title: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Arena — ${stepTitles[c.currentStep.value]}'),
              if (widget.ownerNameOverride != null)
                Text(
                  'For: ${widget.ownerNameOverride}',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
            ],
          ),
        ),
        actions: [
          Obx(() => c.currentStep.value == ArenaFormController.totalSteps - 1
              ? c.isSubmitting.value
                  ? const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(
                      onPressed: c.submit,
                      child: const Text('Submit',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                    )
              : TextButton(
                  onPressed: c.nextStep,
                  child: const Text('Next',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                )),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Obx(
                () => Row(
                  children: List.generate(
                    ArenaFormController.totalSteps,
                    (i) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 5,
                        decoration: BoxDecoration(
                          color: i <= c.currentStep.value
                              ? AppColors.primary
                              : AppColors.textGrey.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Obx(() {
                switch (c.currentStep.value) {
                  case 0:
                    return _basicInfoStep(c);
                  case 1:
                    return _imagesStep(c);
                  default:
                    return _locationStep(c);
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _basicInfoStep(ArenaFormController c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
      ],
    );
  }

  Widget _imagesStep(ArenaFormController c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Add photos of your arena. The first photo becomes the cover.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textGrey),
        ),
        const SizedBox(height: 16),
        Obx(
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
                      Icon(Icons.add_a_photo_outlined,
                          color: AppColors.primary),
                      SizedBox(height: 6),
                      Text('Add', style: TextStyle(color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
              ...List.generate(c.images.length, (i) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ArenaImage(path: c.images[i].path),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => c.removeImage(i),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _locationStep(ArenaFormController c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Obx(() {
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
                c.setLocation(
                  result.latLng,
                  c.addressCtrl.text.isNotEmpty
                      ? c.addressCtrl.text
                      : (result.address ?? 'Pinned location'),
                );
              }
            },
            child: Container(
              height: 180,
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
                    size: 48,
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
        }),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Address',
          hint: 'Street, area, city',
          controller: c.addressCtrl,
          prefixIcon: Icons.location_on_outlined,
          maxLines: 2,
        ),
      ],
    );
  }
}
