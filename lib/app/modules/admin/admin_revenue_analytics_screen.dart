import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/analytics_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/report_filter_bar.dart';

/// Arena revenue analytics — totals, averages, and revenue charts.
class AdminRevenueAnalyticsScreen extends StatelessWidget {
  const AdminRevenueAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AnalyticsController>()) {
      Get.put(AnalyticsController(), permanent: true);
    }
    final c = AnalyticsController.to;

    return Scaffold(
      appBar: AppBar(title: const Text('Revenue Analytics')),
      body: Column(
        children: [
          const ReportFilterBar(showArenaFilter: true),
          Expanded(
            child: Obx(() {
              final stats = c.revenueStats;
              if (stats.isEmpty) {
                return const Center(child: Text('No data for this filter'));
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.payments_outlined,
                              color: AppColors.success),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_pkr(c.totalRevenue),
                                style: AppTextStyles.headlineMedium),
                            Text('Platform revenue · ${c.rangeLabel}',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textGrey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...stats.map(_arenaCard),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _arenaCard(ArenaRevenueStats s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child:
                        Text(s.arena.name, style: AppTextStyles.titleMedium)),
                Text(_pkr(s.total),
                    style: AppTextStyles.titleMedium
                        .copyWith(color: AppColors.success)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _metric('Completed', '${s.completedBookings}'),
                _metric('Avg / booking', _pkr(s.avgBookingValue)),
                _metric('Per day',
                    _pkr(s.daily.isEmpty ? 0 : s.total / s.daily.length)),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < s.daily.length; i++)
                          FlSpot(i.toDouble(), s.daily[i]),
                      ],
                      isCurved: true,
                      barWidth: 3,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                      ),
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.25),
                            AppColors.primary.withValues(alpha: 0.0),
                          ],
                        ),
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

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.bodyMedium),
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textGrey)),
        ],
      ),
    );
  }

  String _pkr(double v) {
    if (v >= 1000) return 'PKR ${(v / 1000).toStringAsFixed(1)}k';
    return 'PKR ${v.toStringAsFixed(0)}';
  }
}
