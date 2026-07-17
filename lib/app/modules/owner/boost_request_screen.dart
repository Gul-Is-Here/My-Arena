import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/boost_controller.dart';
import '../../data/models/boost_request_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/arena_image.dart';

/// Boost / Event promotion request: duration, JazzCash payment proof.
class BoostRequestScreen extends StatelessWidget {
  const BoostRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(BoostController());
    final args = Get.arguments as Map<String, dynamic>;
    final String arenaId = args['arenaId'];
    final String arenaName = args['arenaName'];
    final BoostType type = args['type'] ?? BoostType.boost;
    final bool isEvent = type == BoostType.event;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEvent ? 'Promote Event' : 'Boost Arena'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.stadium_outlined,
                      color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child:
                        Text(arenaName, style: AppTextStyles.titleMedium),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (isEvent) ...[
              Text('Event Details', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Event Name',
                hint: 'e.g. Summer Padel Cup',
                controller: c.eventNameCtrl,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Description',
                hint: 'What is this event about?',
                controller: c.eventDescriptionCtrl,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Obx(
                      () => OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          side: BorderSide(
                            color: AppColors.textGrey.withValues(alpha: 0.4),
                          ),
                        ),
                        icon: const Icon(Icons.event, size: 18),
                        label: Text(
                          c.eventDate.value == null
                              ? 'Event Date'
                              : '${c.eventDate.value!.day}/${c.eventDate.value!.month}/${c.eventDate.value!.year}',
                          style: AppTextStyles.bodyMedium,
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
                          );
                          if (picked != null) c.eventDate.value = picked;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      label: '',
                      hint: 'Attendees',
                      controller: c.eventAttendeesCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            Text('Duration', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            Obx(
              () => Column(
                children: BoostDuration.values.map((duration) {
                  final selected = c.selectedDuration.value == duration;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () => c.selectedDuration.value = duration,
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textGrey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(duration.label,
                                style: AppTextStyles.titleMedium),
                          ),
                          Text(
                            'PKR ${duration.price.toStringAsFixed(0)}',
                            style: AppTextStyles.titleMedium
                                .copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            Text('Payment', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            AppCard(
              color: AppColors.primary.withValues(alpha: 0.08),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          color: AppColors.primary),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Send payment via JazzCash to:',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textGrey)),
                          Obx(() => Text(
                            c.jazzCashNumber.value,
                            style: AppTextStyles.titleLarge
                                .copyWith(color: AppColors.primary),
                          )),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Screenshot upload
            Obx(
              () => c.screenshot.value == null
                  ? AppButton(
                      label: 'Upload Payment Screenshot',
                      icon: Icons.upload_outlined,
                      outlined: true,
                      onPressed: c.pickScreenshot,
                    )
                  : Stack(
                      children: [
                        ArenaImage(
                          path: c.screenshot.value!.path,
                          height: 200,
                          width: double.infinity,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton.filled(
                            style: IconButton.styleFrom(
                                backgroundColor: Colors.black54),
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 18),
                            onPressed: () => c.screenshot.value = null,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),

            Obx(
              () => AppButton(
                label:
                    'Submit — PKR ${c.selectedDuration.value.price.toStringAsFixed(0)}',
                isLoading: c.isSubmitting.value,
                onPressed: () => c.submit(
                  arenaId: arenaId,
                  arenaName: arenaName,
                  type: type,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
