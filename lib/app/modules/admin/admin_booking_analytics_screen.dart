import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/analytics_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/report_filter_bar.dart';

/// Booking analytics — per-arena totals, peak hours, and trends.
class AdminBookingAnalyticsScreen extends StatelessWidget {
  const AdminBookingAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AnalyticsController>()) {
      Get.put(AnalyticsController(), permanent: true);
    }
    final c = AnalyticsController.to;

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Analytics')),
      body: Column(
        children: [
          const ReportFilterBar(showArenaFilter: true),
          Expanded(
            child: Obx(() {
              final stats = c.bookingStats;
              if (stats.isEmpty) {
                return const Center(child: Text('No data for this filter'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: stats.length,
                itemBuilder: (_, i) => _arenaCard(stats[i]),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _arenaCard(ArenaBookingStats s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.arena.name, style: AppTextStyles.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                _metric('Total', '${s.total}', AppColors.primary),
                _metric('Confirmed', '${s.confirmed}', AppColors.success),
                _metric('Cancelled', '${s.cancelled}', AppColors.error),
                _metric('Pending', '${s.pending}', AppColors.warning),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  'Peak hours: ${_hourLabel(s.peakHour)} – ${_hourLabel((s.peakHour + 2) % 24)}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.accent),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Booking trend',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textGrey)),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(enabled: false),
                  barGroups: [
                    for (var i = 0; i < s.trend.length && i < 30; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: s.trend[i],
                          width: s.trend.length > 14 ? 5 : 10,
                          borderRadius: BorderRadius.circular(3),
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [AppColors.primary, AppColors.accent],
                          ),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hourLabel(int h) {
    final period = h >= 12 ? 'PM' : 'AM';
    final display = h % 12 == 0 ? 12 : h % 12;
    return '$display $period';
  }

  Widget _metric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.titleMedium.copyWith(color: color)),
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textGrey)),
        ],
      ),
    );
  }
}
