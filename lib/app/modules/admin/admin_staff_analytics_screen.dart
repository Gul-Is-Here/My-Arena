import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/analytics_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/report_filter_bar.dart';
import '../../widgets/status_badge.dart';

/// Staff analytics — bookings handled, revenue, and performance per staff.
class AdminStaffAnalyticsScreen extends StatelessWidget {
  const AdminStaffAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AnalyticsController>()) {
      Get.put(AnalyticsController(), permanent: true);
    }
    final c = AnalyticsController.to;

    return Scaffold(
      appBar: AppBar(title: const Text('Staff Analytics')),
      body: Column(
        children: [
          const ReportFilterBar(),
          Expanded(
            child: Obx(() {
              final stats = c.staffStats;
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: stats.length,
                itemBuilder: (_, i) => _staffCard(stats[i]),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _staffCard(StaffStats s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(s.name[0],
                      style: AppTextStyles.titleMedium
                          .copyWith(color: AppColors.primary)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: AppTextStyles.titleMedium),
                      Text('Support & booking staff',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textGrey)),
                    ],
                  ),
                ),
                StatusBadge(status: s.isActive ? 'active' : 'off'),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _metric('Handled', '${s.handled}', AppColors.primary),
                _metric('Completed', '${s.completed}', AppColors.success),
                _metric('Cancelled', '${s.cancelled}', AppColors.error),
                _metric(
                    'Revenue',
                    'PKR ${(s.revenue / 1000).toStringAsFixed(0)}k',
                    AppColors.accent),
              ],
            ),
            const SizedBox(height: 14),
            Text(
                'Performance · ${(s.completionRate * 100).toStringAsFixed(0)}% completion',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textGrey)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: s.completionRate,
                minHeight: 8,
                backgroundColor: AppColors.textGrey.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(
                  s.completionRate > 0.8
                      ? AppColors.success
                      : (s.completionRate > 0.6
                          ? AppColors.warning
                          : AppColors.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textGrey)),
        ],
      ),
    );
  }
}
