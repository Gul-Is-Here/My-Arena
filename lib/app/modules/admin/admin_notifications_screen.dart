import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';

/// Admin notifications — bookings, tickets, boosts, tournaments,
/// verifications, payment issues. FCM push in the backend phase.
class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AdminController.to;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: admin.markAllNotificationsRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: Obx(() {
        final items = admin.notifications;
        if (items.isEmpty) {
          return const Center(child: Text('No notifications'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final n = items[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _color(n.type).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          Icon(_icon(n.type), color: _color(n.type), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(n.title,
                                    style: AppTextStyles.titleMedium),
                              ),
                              if (!n.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(n.body, style: AppTextStyles.bodySmall),
                          const SizedBox(height: 4),
                          Text(_timeAgo(n.timestamp),
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textGrey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'booking':
        return Icons.calendar_month;
      case 'ticket':
        return Icons.support_agent;
      case 'boost':
        return Icons.rocket_launch_outlined;
      case 'tournament':
        return Icons.emoji_events_outlined;
      case 'arena':
        return Icons.stadium_outlined;
      default:
        return Icons.payment_outlined;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'booking':
        return AppColors.primary;
      case 'ticket':
        return AppColors.warning;
      case 'boost':
        return AppColors.accent;
      case 'tournament':
        return AppColors.success;
      case 'payment':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
