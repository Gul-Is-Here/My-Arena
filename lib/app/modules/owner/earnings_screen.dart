import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/owner_booking_controller.dart';
import '../../controllers/owner_controller.dart';
import '../../data/models/booking_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

const _bg = AppColors.background;
const _surface = AppColors.surface;
const _surfaceLow = AppColors.elevated;
const _outline = AppColors.border;
const _cyan = AppColors.secondary;
const _greenFixed = AppColors.success;
const _amber = AppColors.warning;
const _onSurface = AppColors.textPrimary;
const _onSurfaceVar = AppColors.textSecondary;

final _pkr = NumberFormat('#,##0');

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  static const _rangeLabels = ['Day', 'Week', 'Month', 'All'];
  static const _ranges = [
    RevenueRange.daily,
    RevenueRange.weekly,
    RevenueRange.monthly,
    null, // null = all time
  ];

  // Stable reactive state — not recreated on every build.
  final _selectedRange = Rx<RevenueRange?>(RevenueRange.monthly);

  List<BookingModel> _paid(List<BookingModel> all) => all
      .where((b) =>
          b.status == BookingStatus.confirmed ||
          b.status == BookingStatus.completed)
      .toList();

  Map<String, double> _byArena(List<BookingModel> p) {
    final map = <String, double>{};
    for (final b in p) {
      map[b.arenaName] = (map[b.arenaName] ?? 0) + b.totalAmount;
    }
    return map;
  }

  Map<String, double> _byCourt(List<BookingModel> p) {
    final map = <String, double>{};
    for (final b in p) {
      final key = '${b.courtName} (${b.arenaName})';
      map[key] = (map[key] ?? 0) + b.totalAmount;
    }
    return map;
  }

  List<BookingModel> _filtered(List<BookingModel> p, RevenueRange? range) {
    if (range == null) return p;
    final now = DateTime.now();
    return p.where((b) {
      switch (range) {
        case RevenueRange.daily:
          return b.date.year == now.year &&
              b.date.month == now.month &&
              b.date.day == now.day;
        case RevenueRange.weekly:
          return now.difference(b.date).inDays < 7;
        case RevenueRange.monthly:
          return b.date.year == now.year && b.date.month == now.month;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bookings = OwnerBookingController.to;
    final selectedRange = _selectedRange;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: Get.back,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _outline),
                      ),
                      child: const Icon(Icons.arrow_back, color: _onSurface, size: 20),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Earnings',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineMedium.copyWith(color: _onSurface, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Obx(() {
                final all = bookings.all;
                final paidList = _paid(all);
                final filteredList = _filtered(paidList, selectedRange.value);
                final total = filteredList.fold(0.0, (a, b) => a + b.totalAmount);
                final arenaMap = _byArena(filteredList);
                final courtMap = _byCourt(filteredList);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  children: [
                    // Total earnings hero
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _surfaceLow,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Earnings', style: AppTextStyles.bodySmall.copyWith(color: _onSurfaceVar, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            'PKR ${_pkr.format(total)}',
                            style: AppTextStyles.scoreboardMedium.copyWith(color: _greenFixed, fontSize: 32, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${filteredList.length} confirmed booking${filteredList.length == 1 ? '' : 's'}',
                            style: AppTextStyles.caption.copyWith(color: _onSurfaceVar, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          // Range chips
                          Row(
                            children: [
                              for (var i = 0; i < _ranges.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () => selectedRange.value = _ranges[i],
                                    child: Obx(() => AnimatedContainer(
                                      duration: const Duration(milliseconds: 160),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: selectedRange.value == _ranges[i]
                                            ? AppColors.primary.withValues(alpha: 0.12)
                                            : _surface,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: selectedRange.value == _ranges[i]
                                              ? AppColors.primary.withValues(alpha: 0.5)
                                              : _outline,
                                        ),
                                      ),
                                      child: Text(
                                        _rangeLabels[i],
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: selectedRange.value == _ranges[i] ? AppColors.primary : _onSurfaceVar,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Per-arena breakdown
                    if (arenaMap.isNotEmpty) ...[
                      Text('By Arena', style: AppTextStyles.titleMedium.copyWith(color: _onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      ...arenaMap.entries.map((e) {
                        final pct = total > 0 ? e.value / total : 0.0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _surfaceLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _outline),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _cyan.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.stadium_outlined, color: _cyan, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      e.key,
                                      style: AppTextStyles.bodyMedium.copyWith(color: _onSurface, fontSize: 14, fontWeight: FontWeight.w700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    'PKR ${_pkr.format(e.value)}',
                                    style: AppTextStyles.scoreboard.copyWith(color: _greenFixed, fontSize: 14, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  backgroundColor: _outline.withValues(alpha: 0.4),
                                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                                  minHeight: 4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(pct * 100).toStringAsFixed(1)}% of total',
                                style: AppTextStyles.caption.copyWith(color: _onSurfaceVar, fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                    ],

                    // Per-court breakdown
                    if (courtMap.isNotEmpty) ...[
                      Text('By Court', style: AppTextStyles.titleMedium.copyWith(color: _onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      ...courtMap.entries.map((e) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _surfaceLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _outline),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: _amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.sports_outlined, color: _amber, size: 15),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                e.key,
                                style: AppTextStyles.bodySmall.copyWith(color: _onSurface, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'PKR ${_pkr.format(e.value)}',
                              style: AppTextStyles.scoreboard.copyWith(color: _onSurface, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 10),
                    ],

                    // Transaction history
                    Text('Transaction History', style: AppTextStyles.titleMedium.copyWith(color: _onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    if (filteredList.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No earnings in this period', style: AppTextStyles.bodyMedium.copyWith(color: _onSurfaceVar)),
                        ),
                      )
                    else
                      ...filteredList.map((b) => _txRow(b)),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _txRow(BookingModel b) {
    final isCompleted = b.status == BookingStatus.completed;
    final color = isCompleted ? _greenFixed : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.payments_outlined, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.courtName,
                  style: AppTextStyles.bodySmall.copyWith(color: _onSurface, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${b.arenaName} • ${_fmtDate(b.date)}',
                  style: AppTextStyles.caption.copyWith(color: _onSurfaceVar, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PKR ${_pkr.format(b.totalAmount)}',
                style: AppTextStyles.scoreboard.copyWith(color: color, fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                b.status.label,
                style: AppTextStyles.caption.copyWith(color: _onSurfaceVar, fontSize: 10.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
