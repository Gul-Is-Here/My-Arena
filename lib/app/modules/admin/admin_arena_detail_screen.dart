import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

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

            // ── Featured & Carousel ───────────────────────────────────
            Text('Featured & Home Carousel', style: AppTextStyles.titleLarge),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // isFeatured row (set by boost system or manually)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Featured Arena',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600)),
                          Text('Appears in "Featured Arenas Near You"',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textGrey)),
                        ],
                      ),
                      Switch(
                        value: a.isFeatured,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) =>
                            AdminController.to.toggleFeatured(a.id, val),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  // showOnHomeCarousel row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Show on Home Carousel',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600)),
                          Text('Appears in the top banner carousel',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textGrey)),
                        ],
                      ),
                      Switch(
                        value: a.showOnHomeCarousel,
                        activeThumbColor: AppColors.secondary,
                        onChanged: (val) => admin.toggleCarousel(
                          a.id,
                          show: val,
                          order: a.carouselOrder,
                        ),
                      ),
                    ],
                  ),
                  if (a.showOnHomeCarousel) ...[
                    const Divider(height: 20),
                    // Carousel order
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Display Order',
                                  style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textGrey)),
                              Text(
                                  'Current position: ${a.carouselOrder == 0 ? 'First' : '#${a.carouselOrder + 1}'}',
                                  style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              color: AppColors.textGrey,
                              onPressed: a.carouselOrder <= 0
                                  ? null
                                  : () => admin.setCarouselOrder(
                                      a.id, a.carouselOrder - 1),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.elevated,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${a.carouselOrder + 1}',
                                style: AppTextStyles.titleMedium,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              color: AppColors.secondary,
                              onPressed: () => admin.setCarouselOrder(
                                  a.id, a.carouselOrder + 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    // Optional scheduling
                    _CarouselScheduleRow(arena: a, admin: admin),
                  ],
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

// ── Carousel schedule row ─────────────────────────────────────────────────────

class _CarouselScheduleRow extends StatelessWidget {
  final ArenaModel arena;
  final AdminController admin;
  const _CarouselScheduleRow({required this.arena, required this.admin});

  static final _fmt = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROMOTIONAL SCHEDULE (optional)',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textGrey,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DateTile(
                label: 'Start Date',
                date: arena.carouselStartDate,
                onPick: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: arena.carouselStartDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (d != null) {
                    await admin.toggleCarousel(
                      arena.id,
                      show: true,
                      order: arena.carouselOrder,
                      startDate: d,
                      endDate: arena.carouselEndDate,
                    );
                  }
                },
                onClear: arena.carouselStartDate == null
                    ? null
                    : () => admin.toggleCarousel(
                          arena.id,
                          show: true,
                          order: arena.carouselOrder,
                          endDate: arena.carouselEndDate,
                        ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DateTile(
                label: 'End Date',
                date: arena.carouselEndDate,
                onPick: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: arena.carouselEndDate ??
                        DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (d != null) {
                    await admin.toggleCarousel(
                      arena.id,
                      show: true,
                      order: arena.carouselOrder,
                      startDate: arena.carouselStartDate,
                      endDate: d,
                    );
                  }
                },
                onClear: arena.carouselEndDate == null
                    ? null
                    : () => admin.toggleCarousel(
                          arena.id,
                          show: true,
                          order: arena.carouselOrder,
                          startDate: arena.carouselStartDate,
                        ),
              ),
            ),
          ],
        ),
        if (arena.carouselStartDate != null || arena.carouselEndDate != null) ...[
          const SizedBox(height: 8),
          Text(
            arena.carouselStartDate != null && arena.carouselEndDate != null
                ? 'Visible ${_fmt.format(arena.carouselStartDate!)} – ${_fmt.format(arena.carouselEndDate!)}'
                : arena.carouselStartDate != null
                    ? 'Starts ${_fmt.format(arena.carouselStartDate!)}'
                    : 'Ends ${_fmt.format(arena.carouselEndDate!)}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.secondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  const _DateTile({
    required this.label,
    required this.date,
    required this.onPick,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: date != null ? AppColors.secondary : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined,
                size: 15,
                color:
                    date != null ? AppColors.secondary : AppColors.textGrey),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 9,
                          color: AppColors.textGrey,
                          letterSpacing: 0.5)),
                  Text(
                    date != null
                        ? DateFormat('MMM d, yy').format(date!)
                        : 'Not set',
                    style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: date != null
                            ? AppColors.textPrimary
                            : AppColors.textGrey),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 14, color: AppColors.textGrey),
              ),
          ],
        ),
      ),
    );
  }
}
