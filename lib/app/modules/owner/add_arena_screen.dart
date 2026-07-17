import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/arena_form_controller.dart';
import '../../data/models/court_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/location_picker.dart';
import '../../widgets/arena_image.dart';
import 'add_court_bottom_sheet.dart';

/// Multi-step Add Arena flow:
/// Basic Info → Images → Location → Courts → Review & Submit.
class AddArenaScreen extends StatelessWidget {
  const AddArenaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ArenaFormController());
    const stepTitles = [
      'Basic Info',
      'Photos',
      'Location',
      'Courts',
      'Review',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            'Add Arena — ${stepTitles[c.currentStep.value]}',
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step progress bar
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
                  case 2:
                    return _locationStep(c);
                  case 3:
                    return _courtsStep(context, c);
                  default:
                    return _reviewStep(c);
                }
              }),
            ),
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Obx(
                () => Row(
                  children: [
                    if (c.currentStep.value > 0)
                      Expanded(
                        child: AppButton(
                          label: 'Back',
                          outlined: true,
                          onPressed: c.previousStep,
                        ),
                      ),
                    if (c.currentStep.value > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child:
                          c.currentStep.value == ArenaFormController.totalSteps - 1
                              ? AppButton(
                                  label: 'Submit for Review',
                                  isLoading: c.isSubmitting.value,
                                  onPressed: c.submit,
                                )
                              : AppButton(
                                  label: 'Continue',
                                  onPressed: c.nextStep,
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 1 — Basic info
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

  // Step 2 — Images
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

  // Step 3 — Location
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
                  c.addressCtrl.text.isEmpty
                      ? '${result.latLng.latitude.toStringAsFixed(5)}, ${result.latLng.longitude.toStringAsFixed(5)}'
                      : c.addressCtrl.text,
                );
              }
            },
            child: AppCard(
              padding: EdgeInsets.zero,
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

  // Step 4 — Courts
  Widget _courtsStep(BuildContext context, ArenaFormController c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppButton(
          label: 'Add Court',
          icon: Icons.add,
          outlined: true,
          onPressed: () =>
              AddCourtBottomSheet.show(context, onAdd: c.addCourt),
        ),
        const SizedBox(height: 16),
        Obx(
          () => Column(
            children: List.generate(c.courts.length, (i) {
              final court = c.courts[i];
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
                        child: Icon(_courtIcon(court.type),
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(court.name,
                                style: AppTextStyles.titleMedium),
                            Text(
                              '${court.type.label} · ${court.capacity} players · '
                              '${court.startTime}–${court.endTime}',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'PKR ${court.pricePerHour.toStringAsFixed(0)}/hr',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.primary),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: AppColors.error),
                            onPressed: () => c.removeCourt(i),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // Step 5 — Review
  Widget _reviewStep(ArenaFormController c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.images.isNotEmpty)
                ArenaImage(
                  path: c.images.first.path,
                  height: 160,
                  width: double.infinity,
                ),
              const SizedBox(height: 16),
              Text(c.nameCtrl.text, style: AppTextStyles.headlineMedium),
              const SizedBox(height: 8),
              Text(
                c.descriptionCtrl.text,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textGrey),
              ),
              const SizedBox(height: 16),
              _reviewRow(Icons.location_on_outlined, c.addressCtrl.text),
              _reviewRow(Icons.photo_library_outlined,
                  '${c.images.length} photo${c.images.length == 1 ? '' : 's'}'),
              _reviewRow(Icons.sports_tennis,
                  '${c.courts.length} court${c.courts.length == 1 ? '' : 's'}'),
              const SizedBox(height: 16),
              AppCard(
                color: AppColors.warning.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your arena will be reviewed by our team before it '
                        'becomes visible to customers.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
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
