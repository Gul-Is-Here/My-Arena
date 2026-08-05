import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/admin_booking_controller.dart';
import '../../data/models/booking_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  late final AdminBookingController _ctrl;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<AdminBookingController>()) {
      Get.put(AdminBookingController());
    }
    _ctrl = AdminBookingController.to;
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        _ctrl.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Booking Management'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  controller: _searchCtrl,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search by customer, arena, or ID…',
                    hintStyle: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textSecondary, size: 20),
                    filled: true,
                    fillColor: AppColors.elevated,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => _ctrl.searchQuery.value = v,
                ),
              ),
              _StatusFilterBar(),
            ],
          ),
        ),
      ),
      body: Obx(() {
        final list = _ctrl.filtered;
        if (_ctrl.isLoading.value && list.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month_outlined,
                    color: AppColors.textSecondary, size: 48),
                const SizedBox(height: 12),
                Text('No bookings found',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(12),
          itemCount: list.length + (_ctrl.hasMore.value ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i == list.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary)),
              );
            }
            return _BookingTile(booking: list[i]);
          },
        );
      }),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ctrl = AdminBookingController.to;
    final statuses = [
      null,
      BookingStatus.pendingDeposit,
      BookingStatus.depositSubmitted,
      BookingStatus.confirmed,
      BookingStatus.completed,
      BookingStatus.cancelled,
      BookingStatus.refundPending,
    ];
    return Obx(() {
      final current = ctrl.statusFilter.value;
      return SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          itemCount: statuses.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            final s = statuses[i];
            final label = s == null ? 'All' : s.label;
            final selected = current == s;
            return GestureDetector(
              onTap: () => ctrl.statusFilter.value = s,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.elevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: selected ? AppColors.onPrimary : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

class _BookingTile extends StatelessWidget {
  final BookingModel booking;
  const _BookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final color = _statusColor(b.status);
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.adminBookingDetail, arguments: b),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(b.customerName,
                      style: AppTextStyles.titleMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(b.status.label,
                      style: AppTextStyles.caption
                          .copyWith(color: color, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${b.arenaName} • ${b.courtName}',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    color: AppColors.textSecondary, size: 13),
                const SizedBox(width: 4),
                Text(DateFormat('d MMM yyyy').format(b.date),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                const Icon(Icons.access_time,
                    color: AppColors.textSecondary, size: 13),
                const SizedBox(width: 4),
                Text(b.timeRange,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                const Spacer(),
                Text(
                  'PKR ${b.totalAmount.toStringAsFixed(0)}',
                  style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('ID: ${b.id}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textDisabled, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(BookingStatus s) => switch (s) {
        BookingStatus.confirmed => AppColors.success,
        BookingStatus.completed => AppColors.secondary,
        BookingStatus.cancelled ||
        BookingStatus.rejected =>
          AppColors.error,
        BookingStatus.refundPending ||
        BookingStatus.refundSent ||
        BookingStatus.refundConfirmed =>
          AppColors.warning,
        _ => AppColors.textSecondary,
      };
}
