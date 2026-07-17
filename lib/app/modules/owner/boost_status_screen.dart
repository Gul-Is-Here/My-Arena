import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/boost_controller.dart';
import '../../data/models/boost_request_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';

/// List of the owner's boost / event promotion requests with statuses.
class BoostStatusScreen extends StatelessWidget {
  const BoostStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(BoostController(), permanent: true);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Boosts & Events', style: AppTextStyles.displayLarge),
          ),
          Expanded(
            child: Obx(
              () => c.requests.isEmpty
                  ? Center(
                      child: Text(
                        'No boost requests yet',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textGrey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: c.requests.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _requestCard(c.requests[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(BoostRequestModel request) {
    final bool isEvent = request.type == BoostType.event;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEvent
                      ? Icons.campaign_outlined
                      : Icons.rocket_launch_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.arenaName,
                        style: AppTextStyles.titleMedium),
                    Text(
                      '${isEvent ? 'Event Promotion' : 'Arena Boost'} · ${request.duration.label}',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: request.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('d MMM yyyy · h:mm a').format(request.createdAt),
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textGrey),
              ),
              Text(
                'PKR ${request.price.toStringAsFixed(0)}',
                style:
                    AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
