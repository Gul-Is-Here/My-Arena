import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/owner_booking_controller.dart';
import '../../controllers/owner_controller.dart';
import '../../data/models/booking_model.dart';

const _bg = Color(0xFF10131A);
const _surface = Color(0xFF1D2026);
const _surfaceLow = Color(0xFF191C22);
const _outline = Color(0xFF3B494B);
const _cyan = Color(0xFF00DBE9);
const _greenFixed = Color(0xFF79FF5B);
const _amber = Color(0xFFFFB59C);
const _onSurface = Color(0xFFE1E2EB);
const _onSurfaceVar = Color(0xFFB9CACB);

final _pkr = NumberFormat('#,##0');

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  static const _rangeLabels = ['Day', 'Week', 'Month', 'All'];
  static const _ranges = [
    RevenueRange.daily,
    RevenueRange.weekly,
    RevenueRange.monthly,
    null, // null = all time
  ];

  @override
  Widget build(BuildContext context) {
    final bookings = OwnerBookingController.to;
    final selectedRange = Rx<RevenueRange?>(RevenueRange.monthly);

    List<BookingModel> paid(List<BookingModel> all) => all.where((b) =>
        b.status == BookingStatus.confirmed ||
        b.status == BookingStatus.completed).toList();

    Map<String, double> byArena(List<BookingModel> p) {
      final map = <String, double>{};
      for (final b in p) {
        map[b.arenaName] = (map[b.arenaName] ?? 0) + b.totalAmount;
      }
      return map;
    }

    Map<String, double> byCourt(List<BookingModel> p) {
      final map = <String, double>{};
      for (final b in p) {
        final key = '${b.courtName} (${b.arenaName})';
        map[key] = (map[key] ?? 0) + b.totalAmount;
      }
      return map;
    }

    List<BookingModel> filtered(List<BookingModel> p, RevenueRange? range) {
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
                  const Expanded(
                    child: Text(
                      'Earnings',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _onSurface, fontSize: 22, fontWeight: FontWeight.w800),
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
                final paidList = paid(all);
                final filteredList = filtered(paidList, selectedRange.value);
                final total = filteredList.fold(0.0, (a, b) => a + b.totalAmount);
                final arenaMap = byArena(filteredList);
                final courtMap = byCourt(filteredList);

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
                          const Text('Total Earnings', style: TextStyle(color: _onSurfaceVar, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            'PKR ${_pkr.format(total)}',
                            style: const TextStyle(color: _greenFixed, fontSize: 32, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${filteredList.length} confirmed booking${filteredList.length == 1 ? '' : 's'}',
                            style: const TextStyle(color: _onSurfaceVar, fontSize: 12),
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
                                            ? _cyan.withValues(alpha: 0.18)
                                            : _surface,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: selectedRange.value == _ranges[i]
                                              ? _cyan.withValues(alpha: 0.6)
                                              : _outline,
                                        ),
                                      ),
                                      child: Text(
                                        _rangeLabels[i],
                                        style: TextStyle(
                                          color: selectedRange.value == _ranges[i] ? _cyan : _onSurfaceVar,
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
                      const Text('By Arena', style: TextStyle(color: _onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
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
                                      style: const TextStyle(color: _onSurface, fontSize: 14, fontWeight: FontWeight.w700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    'PKR ${_pkr.format(e.value)}',
                                    style: const TextStyle(color: _greenFixed, fontSize: 14, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  backgroundColor: _outline.withValues(alpha: 0.4),
                                  valueColor: const AlwaysStoppedAnimation(_cyan),
                                  minHeight: 4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(pct * 100).toStringAsFixed(1)}% of total',
                                style: const TextStyle(color: _onSurfaceVar, fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                    ],

                    // Per-court breakdown
                    if (courtMap.isNotEmpty) ...[
                      const Text('By Court', style: TextStyle(color: _onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
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
                                style: const TextStyle(color: _onSurface, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'PKR ${_pkr.format(e.value)}',
                              style: const TextStyle(color: _onSurface, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 10),
                    ],

                    // Transaction history
                    const Text('Transaction History', style: TextStyle(color: _onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    if (filteredList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No earnings in this period', style: TextStyle(color: _onSurfaceVar)),
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
    final color = isCompleted ? _greenFixed : _cyan;
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
                  style: const TextStyle(color: _onSurface, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${b.arenaName} • ${_fmtDate(b.date)}',
                  style: const TextStyle(color: _onSurfaceVar, fontSize: 11.5),
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
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                b.status.label,
                style: const TextStyle(color: _onSurfaceVar, fontSize: 10.5),
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
