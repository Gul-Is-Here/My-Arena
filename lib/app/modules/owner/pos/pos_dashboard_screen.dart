import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../controllers/owner_booking_controller.dart';
import '../../../controllers/owner_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../data/models/arena_model.dart';
import '../../../data/models/booking_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

final _pkr = NumberFormat('#,##0');

class PosDashboardScreen extends StatelessWidget {
  const PosDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    _ensureControllers();
    final pos = PosController.to;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(pos: pos),
            Expanded(
              child: RefreshIndicator(
                onRefresh: pos.refreshStats,
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 720;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      children: [
                        const SizedBox(height: 16),
                        _StatsGrid(pos: pos, isWide: isWide),
                        const SizedBox(height: 20),
                        _QuickActions(isWide: isWide),
                        const SizedBox(height: 20),
                        _TodayBookings(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _ensureControllers() {
    if (!Get.isRegistered<OwnerController>()) Get.put(OwnerController());
    if (!Get.isRegistered<OwnerBookingController>()) {
      Get.put(OwnerBookingController(), permanent: true);
    }
    if (!Get.isRegistered<PosController>()) {
      Get.put(PosController(), permanent: true);
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final PosController pos;
  const _Header({required this.pos});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: Get.back,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.point_of_sale, color: AppColors.onPrimary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('POS', style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
                Obx(() {
                  final arena = pos.selectedArena.value;
                  return Text(
                    arena?.name ?? 'Select Arena',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  );
                }),
              ],
            ),
          ),
          // Arena selector
          Obx(() {
            final arenas = OwnerController.to.myArenas;
            if (arenas.length <= 1) return const SizedBox.shrink();
            return GestureDetector(
              onTap: () => _showArenaSelector(arenas),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz, color: AppColors.textSecondary, size: 16),
                    const SizedBox(width: 4),
                    Text('Switch', style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          // Shift indicator
          Obx(() {
            final shift = pos.openShift.value;
            return GestureDetector(
              onTap: () => Get.toNamed(AppRoutes.posShift),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: shift != null
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.elevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: shift != null
                        ? AppColors.success.withValues(alpha: 0.4)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      shift != null ? Icons.circle : Icons.circle_outlined,
                      color: shift != null ? AppColors.success : AppColors.textSecondary,
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      shift != null ? 'Shift Open' : 'No Shift',
                      style: AppTextStyles.caption.copyWith(
                        color: shift != null ? AppColors.success : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showArenaSelector(List<ArenaModel> arenas) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Select Arena', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...arenas.map((a) => ListTile(
                  title: Text(a.name, style: AppTextStyles.bodyMedium),
                  subtitle: Text(a.location.address, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  trailing: Obx(() => pos.selectedArena.value?.id == a.id
                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                      : const SizedBox.shrink()),
                  onTap: () {
                    pos.selectArena(a);
                    Get.back();
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Stats Grid ────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final PosController pos;
  final bool isWide;
  const _StatsGrid({required this.pos, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (pos.statsLoading.value) {
        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
      }

      final bookings = OwnerBookingController.to.all;
      final now = DateTime.now();
      final todayBookings = bookings.where((b) =>
          b.date.year == now.year &&
          b.date.month == now.month &&
          b.date.day == now.day).toList();
      final walkIns = todayBookings.where((b) => b.isPosBooking).length;
      final online = todayBookings.where((b) => !b.isPosBooking).length;

      final arena = pos.selectedArena.value;
      final courts = arena?.courts ?? [];
      final availableCourts = courts.where((c) =>
          pos.courtStatus(c.id) == CourtLiveStatus.available).length;
      final occupiedCourts = courts.where((c) =>
          pos.courtStatus(c.id) == CourtLiveStatus.occupied).length;

      final stats = [
        _StatData('Today Revenue', 'PKR ${_pkr.format(pos.todayRevenue.value)}', AppColors.primary, Icons.attach_money),
        _StatData('Paid', 'PKR ${_pkr.format(pos.todayPaid.value)}', AppColors.success, Icons.check_circle_outline),
        _StatData('Outstanding', 'PKR ${_pkr.format(pos.todayRemaining.value)}', AppColors.warning, Icons.pending_outlined),
        _StatData('Net Revenue', 'PKR ${_pkr.format(pos.todayNet.value)}', AppColors.secondary, Icons.trending_up),
        _StatData('Today Bookings', '${todayBookings.length}', AppColors.textPrimary, Icons.calendar_today_outlined),
        _StatData('Walk-in', '$walkIns', AppColors.accent, Icons.directions_walk),
        _StatData('Online', '$online', AppColors.secondary, Icons.wifi_outlined),
        _StatData('Expenses', 'PKR ${_pkr.format(pos.todayExpenses.value)}', AppColors.error, Icons.receipt_outlined),
        _StatData('Available Courts', '$availableCourts', AppColors.success, Icons.stadium_outlined),
        _StatData('Occupied', '$occupiedCourts', AppColors.warning, Icons.sports_outlined),
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.today, color: AppColors.textSecondary, size: 16),
            const SizedBox(width: 6),
            Text(
              DateFormat('EEEE, d MMM').format(DateTime.now()),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ]),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 5 : 2,
              childAspectRatio: isWide ? 1.4 : 1.6,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: stats.length,
            itemBuilder: (_, i) => _StatCard(data: stats[i]),
          ),
        ],
      );
    });
  }
}

class _StatData {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatData(this.label, this.value, this.color, this.icon);
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, color: data.color, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                data.label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final bool isWide;
  const _QuickActions({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action('New Walk-in', Icons.add_circle_outline, AppColors.primary,
          () => Get.toNamed(AppRoutes.posWalkIn)),
      _Action('Court View', Icons.grid_view_outlined, AppColors.secondary,
          () => Get.toNamed(AppRoutes.posLiveCourts)),
      _Action('Transactions', Icons.receipt_long_outlined, AppColors.accent,
          () => Get.toNamed(AppRoutes.posTransactions)),
      _Action('Expenses', Icons.money_off_outlined, AppColors.warning,
          () => Get.toNamed(AppRoutes.posExpenses)),
      _Action('Reports', Icons.bar_chart_outlined, AppColors.success,
          () => Get.toNamed(AppRoutes.posReports)),
      _Action('Shift', Icons.access_time_outlined, AppColors.textSecondary,
          () => Get.toNamed(AppRoutes.posShift)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppTextStyles.titleMedium.copyWith(
          color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 6 : 3,
            childAspectRatio: 0.9,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: actions.length,
          itemBuilder: (_, i) => _ActionCard(action: actions[i]),
        ),
      ],
    );
  }
}

class _Action {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Action(this.label, this.icon, this.color, this.onTap);
}

class _ActionCard extends StatelessWidget {
  final _Action action;
  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, color: action.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Today's Bookings ──────────────────────────────────────────────────────

class _TodayBookings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final now = DateTime.now();
      final all = OwnerBookingController.to.all;
      final today = all.where((b) =>
          b.date.year == now.year &&
          b.date.month == now.month &&
          b.date.day == now.day &&
          !b.isCancelled).toList()
        ..sort((a, b) => a.startHour.compareTo(b.startHour));

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("Today's Bookings", style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${today.length}', style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          if (today.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: Text('No bookings today', style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary)),
            )
          else
            ...today.map((b) => _TodayBookingRow(booking: b)),
        ],
      );
    });
  }
}

class _TodayBookingRow extends StatelessWidget {
  final BookingModel booking;
  const _TodayBookingRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isNow = booking.startHour <= now.hour &&
        now.hour < booking.startHour + booking.totalHours;
    final isPast = booking.endDateTime.isBefore(now);

    Color statusColor;
    if (isNow) statusColor = AppColors.success;
    else if (isPast) statusColor = AppColors.textDisabled;
    else statusColor = AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: isNow
            ? [BoxShadow(color: AppColors.success.withValues(alpha: 0.1), blurRadius: 8)]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(booking.timeRange, style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary, fontSize: 11)),
              Text(booking.courtName, style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              booking.customerName.isNotEmpty ? booking.customerName : 'Walk-in',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isNow ? 'LIVE' : isPast ? 'Done' : booking.status.label,
              style: AppTextStyles.caption.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
