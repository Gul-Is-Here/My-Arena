import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../data/models/boost_request_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';

/// Boost management — Pending | Approved | Rejected, with payment details.
class AdminBoostsScreen extends StatelessWidget {
  const AdminBoostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AdminController.to;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Boost Management'),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textGrey,
            tabs: [
              Obx(() => Tab(text: 'Pending (${admin.pendingBoosts.length})')),
              const Tab(text: 'Approved'),
              const Tab(text: 'Rejected'),
            ],
          ),
        ),
        body: Obx(() {
          admin.boosts.length;
          return TabBarView(
            children: [
              _list(admin.pendingBoosts, admin, pending: true),
              _list(admin.activeBoosts, admin, pending: false),
              _list(
                admin.boosts.where((b) => b.status == 'rejected').toList(),
                admin,
                pending: false,
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _list(List<BoostRequestModel> items, AdminController admin,
      {required bool pending}) {
    if (items.isEmpty) {
      return Center(
        child: Text('No boost requests here',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textGrey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final b = items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            onTap: () => _paymentSheet(b),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.rocket_launch_outlined,
                          color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.arenaName, style: AppTextStyles.titleMedium),
                          Text(
                            '${b.duration.label} · PKR ${b.price.toStringAsFixed(0)} · tap for payment',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: b.status),
                  ],
                ),
                if (pending) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              admin.setBoostStatus(b.id, 'rejected'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              admin.setBoostStatus(b.id, 'approved'),
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _paymentSheet(BoostRequestModel b) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Payment details',
                        style: AppTextStyles.titleLarge)),
                StatusBadge(status: b.status),
              ],
            ),
            const SizedBox(height: 16),
            _row('Arena', b.arenaName),
            _row('Boost type',
                b.type == BoostType.boost ? 'Arena boost' : 'Event boost'),
            _row('Duration', b.duration.label),
            _row('Amount', 'PKR ${b.price.toStringAsFixed(0)}'),
            _row('Paid from',
                b.accountUsed.isEmpty ? 'JazzCash · 0300-1234567' : b.accountUsed),
            _row('Requested',
                '${b.createdAt.day}/${b.createdAt.month}/${b.createdAt.year}'),
            const SizedBox(height: 14),
            // Screenshot stub — real image from Storage in backend phase.
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, color: AppColors.primary, size: 36),
                  SizedBox(height: 8),
                  Text('Payment screenshot',
                      style: TextStyle(color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textGrey)),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}
