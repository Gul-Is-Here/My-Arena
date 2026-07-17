import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../controllers/analytics_controller.dart';
import '../../data/models/arena_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';

/// Admin view of a single arena — owner details, document verification,
/// activate/suspend controls, revenue and booking history.
class AdminArenaDetailScreen extends StatelessWidget {
  const AdminArenaDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AdminController.to;
    if (!Get.isRegistered<AnalyticsController>()) {
      Get.put(AnalyticsController(), permanent: true);
    }
    final id = Get.arguments as String;

    return Scaffold(
      appBar: AppBar(title: const Text('Arena Detail')),
      body: Obx(() {
        final a = admin.arenas.firstWhereOrNull((x) => x.id == id);
        if (a == null) {
          return const Center(child: Text('Arena not found'));
        }
        final owner = admin.ownerOf(a.ownerId);
        final docsVerified = admin.verifiedArenaDocs.contains(a.id);
        final stats = AnalyticsController.to.bookingStats
            .firstWhereOrNull((s) => s.arena.id == a.id);
        final revenue = AnalyticsController.to.revenueStats
            .firstWhereOrNull((s) => s.arena.id == a.id);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Header ────────────────────────────────────────────────
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child:
                              Text(a.name, style: AppTextStyles.titleLarge)),
                      StatusBadge(status: a.status.name),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(a.location.address,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textGrey)),
                  const SizedBox(height: 8),
                  Text(
                      '${a.courts.length} court${a.courts.length == 1 ? '' : 's'} · Rating ${a.rating}',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textGrey)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Owner details ─────────────────────────────────────────
            Text('Owner', style: AppTextStyles.titleLarge),
            const SizedBox(height: 10),
            AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.15),
                    child: const Icon(Icons.person_outline,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(owner?.name ?? 'Unknown owner',
                            style: AppTextStyles.titleMedium),
                        Text(
                            '${owner?.email ?? '—'} · ${owner?.phone ?? '—'}',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textGrey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Documents ─────────────────────────────────────────────
            Text('Documents', style: AppTextStyles.titleLarge),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                children: [
                  _docRow('CNIC / Ownership proof'),
                  _docRow('Business registration'),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Icon(
                        docsVerified
                            ? Icons.verified_outlined
                            : Icons.gpp_maybe_outlined,
                        color: docsVerified
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          docsVerified
                              ? 'Documents verified'
                              : 'Verification pending',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: docsVerified
                                  ? AppColors.success
                                  : AppColors.warning),
                        ),
                      ),
                      TextButton(
                        onPressed: () => admin.toggleDocsVerified(a.id),
                        child: Text(docsVerified ? 'Unverify' : 'Verify'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Performance ───────────────────────────────────────────
            Text('Performance (this week)', style: AppTextStyles.titleLarge),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _stat('Bookings', '${stats?.total ?? 0}',
                      Icons.calendar_month, AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _stat(
                      'Revenue',
                      'PKR ${((revenue?.total ?? 0) / 1000).toStringAsFixed(0)}k',
                      Icons.payments_outlined,
                      AppColors.success),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(14),
              onTap: () => Get.toNamed(AppRoutes.adminBookingAnalytics),
              child: const Row(
                children: [
                  Icon(Icons.history, color: AppColors.accent),
                  SizedBox(width: 12),
                  Expanded(
                      child: Text('Booking history & trends',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600))),
                  Icon(Icons.chevron_right, color: AppColors.textGrey),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Controls ──────────────────────────────────────────────
            Text('Controls', style: AppTextStyles.titleLarge),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        a.isActive
                            ? 'Visible to customers'
                            : 'Hidden (OFF)',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: a.isActive
                                ? AppColors.success
                                : AppColors.error),
                      ),
                      Switch(
                        value: a.isActive,
                        activeThumbColor: AppColors.success,
                        onChanged: (_) => admin.toggleArenaActive(a.id),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (a.status == ArenaStatus.suspended)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success),
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Reinstate Arena'),
                        onPressed: () =>
                            admin.setArenaStatus(a.id, ArenaStatus.approved),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        icon: const Icon(Icons.block),
                        label: const Text('Suspend Arena'),
                        onPressed: () => Get.defaultDialog(
                          title: 'Suspend arena?',
                          middleText:
                              '${a.name} will be hidden from customers and the owner will be notified.',
                          textCancel: 'Cancel',
                          textConfirm: 'Suspend',
                          confirmTextColor: Colors.white,
                          buttonColor: AppColors.error,
                          onConfirm: () {
                            admin.setArenaStatus(
                                a.id, ArenaStatus.suspended);
                            Get.back();
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _docRow(String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.description_outlined,
              size: 18, color: AppColors.textGrey),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: AppTextStyles.bodyMedium)),
          TextButton(
            onPressed: () => Get.snackbar('Document', 'Viewer opens here '
                'once file storage is wired.'),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.headlineMedium),
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textGrey)),
        ],
      ),
    );
  }
}
