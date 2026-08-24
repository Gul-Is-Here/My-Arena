import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/booking_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class AvailabilityAlertsScreen extends StatelessWidget {
  const AvailabilityAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<BookingController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Availability Alerts',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: Get.back,
        ),
      ),
      body: Obx(() {
        final items = ctrl.waitlistItems;
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_none_outlined,
                    size: 60, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text('No alerts set',
                    style: AppTextStyles.titleMedium
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text(
                  'When a slot you want becomes available,\nyou\'ll be notified here.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (_, i) => _AlertCard(item: items[i], ctrl: ctrl),
        );
      }),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final BookingController ctrl;
  const _AlertCard({required this.item, required this.ctrl});

  String get _dateLabel {
    final ts = item['date'];
    if (ts == null) return '';
    final d = ts.toDate() as DateTime;
    return DateFormat('EEE, d MMM').format(d);
  }

  String get _hourLabel {
    final h = (item['hour'] as int?) ?? 0;
    final hh = h % 24;
    final suffix = hh >= 12 ? 'PM' : 'AM';
    final display = hh % 12 == 0 ? 12 : hh % 12;
    return '$display:00 $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.notifications_active_outlined,
              color: AppColors.primary, size: 22),
        ),
        title: Text(
          item['arenaName'] as String? ?? 'Arena',
          style: AppTextStyles.bodyMedium
              .copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$_dateLabel at $_hourLabel',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.close,
              color: AppColors.textSecondary.withValues(alpha: 0.7), size: 20),
          onPressed: () {
            final id = item['id'] as String?;
            if (id != null) ctrl.cancelWaitlistItem(id);
          },
        ),
      ),
    );
  }
}
