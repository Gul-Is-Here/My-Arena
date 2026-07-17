import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/owner_booking_controller.dart';
import '../../controllers/owner_controller.dart';
import '../../data/models/booking_model.dart';
import '../../routes/app_routes.dart';

const _bg = Color(0xFF10131A);
const _surface = Color(0xFF1D2026);
const _surfaceLow = Color(0xFF191C22);
const _outline = Color(0xFF3B494B);
const _cyan = Color(0xFF00DBE9);
const _greenFixed = Color(0xFF79FF5B);
const _amber = Color(0xFFFFB59C);
const _red = Color(0xFFFFB4AB);
const _onSurface = Color(0xFFE1E2EB);
const _onSurfaceVar = Color(0xFFB9CACB);

final _pkr = NumberFormat('#,##0');

/// Owner Dashboard tab — dark "Arena Command" glass theme, stat cards,
/// neon revenue graph, quick actions and recent activity.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  static const _tabs = [
    RevenueRange.daily,
    RevenueRange.weekly,
    RevenueRange.monthly,
  ];
  static const _tabLabels = ['Day', 'Week', 'Month'];

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final owner = OwnerController.to;
    if (!Get.isRegistered<OwnerBookingController>()) {
      Get.put(OwnerBookingController(), permanent: true);
    }
    final ownerBookings = OwnerBookingController.to;

    return Container(
      color: _bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            Obx(() {
              final today = DateTime.now();
              final bookingsToday = ownerBookings.all
                  .where((b) => _isSameDay(b.date, today))
                  .length;
              final pendingCount = ownerBookings.pendingApproval.length;
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  _statCard(
                    icon: Icons.payments_outlined,
                    iconColor: _greenFixed,
                    label: 'Total Earnings',
                    value: 'PKR ${_pkr.format(owner.totalEarnings.value)}',
                    onTap: () => Get.toNamed(AppRoutes.ownerBookings),
                  ),
                  _statCard(
                    icon: Icons.calendar_month_outlined,
                    iconColor: _cyan,
                    label: 'Bookings Today',
                    value: '$bookingsToday',
                    onTap: () => Get.toNamed(AppRoutes.ownerBookings),
                  ),
                  _statCard(
                    icon: Icons.stadium_outlined,
                    iconColor: _onSurfaceVar,
                    label: 'Active Courts',
                    value: '${owner.activeCourts}',
                    onTap: () => Get.toNamed(AppRoutes.myArenas),
                  ),
                  _statCard(
                    icon: Icons.hourglass_top_outlined,
                    iconColor: _amber,
                    label: 'Pending Approvals',
                    value: '$pendingCount',
                    badge: pendingCount > 0 ? 'ACTION NEEDED' : null,
                    onTap: () => Get.toNamed(AppRoutes.ownerBookings),
                  ),
                ],
              );
            }),
            const SizedBox(height: 20),
            _buildRevenueCard(owner, ownerBookings),
            const SizedBox(height: 20),
            _buildQuickActions(),
            const SizedBox(height: 24),
            const Text(
              'Recent Activity',
              style: TextStyle(
                  color: _onSurface, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _buildRecentActivity(ownerBookings),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = AuthController.to.currentUser;
    return Obx(() {
      final u = user.value;
      return Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: (u?.avatar.isNotEmpty ?? false)
                ? Image.network(u!.avatar, fit: BoxFit.cover)
                : const Icon(Icons.person, color: _onSurfaceVar),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${_greeting()}, ${u?.name.isNotEmpty == true ? u!.name.split(' ').first : 'there'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _onSurface,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('👋', style: TextStyle(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  "Here's your arena summary",
                  style: TextStyle(color: _onSurfaceVar, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _outline),
            ),
            child: const Icon(Icons.notifications_outlined,
                color: _onSurfaceVar, size: 20),
          ),
        ],
      );
    });
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? badge,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surfaceLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  if (badge != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _amber.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _amber.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: _amber,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _onSurfaceVar, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueCard(OwnerController owner, OwnerBookingController ownerBookings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            final points = owner.revenuePoints(ownerBookings.bookings);
            final total = points.fold(0.0, (a, b) => a + b);
            return Row(
              children: [
                const Expanded(
                  child: Text(
                    'Revenue Overview',
                    style: TextStyle(
                        color: _onSurface, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  'PKR ${_pkr.format(total)}',
                  style: const TextStyle(
                      color: _greenFixed, fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ],
            );
          }),
          const SizedBox(height: 10),
          Obx(
            () => Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    _rangeChip(
                      _tabLabels[i],
                      owner.revenueRange.value == _tabs[i],
                      () => owner.revenueRange.value = _tabs[i],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Obx(() {
              final points = owner.revenuePoints(ownerBookings.bookings);
              final labels = owner.revenueLabels;
              final maxY = points.fold(0.0, (a, b) => a > b ? a : b);
              final chartMax = maxY < 1 ? 1000.0 : maxY * 1.25;
              return LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: _outline.withValues(alpha: 0.3),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, _) {
                          final i = value.toInt();
                          if (i < 0 || i >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[i],
                              style: const TextStyle(
                                  color: _onSurfaceVar, fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (points.length - 1).toDouble(),
                  minY: 0,
                  maxY: chartMax,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => _surface,
                      getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                        'PKR ${_pkr.format(s.y)}',
                        const TextStyle(
                            color: _cyan, fontSize: 12, fontWeight: FontWeight.w700),
                      )).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i]),
                      ],
                      isCurved: true,
                      barWidth: 3,
                      color: _cyan,
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, data) =>
                            spot.x == data.spots.last.x,
                        getDotPainter: (spot, pct, data, i) => FlDotCirclePainter(
                          radius: 5,
                          color: _greenFixed,
                          strokeColor: _bg,
                          strokeWidth: 2,
                        ),
                      ),
                      shadow: Shadow(
                        color: _cyan.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _cyan.withValues(alpha: 0.22),
                            _cyan.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _rangeChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _cyan.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _cyan : _onSurfaceVar,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _quickAction(Icons.stadium_outlined, 'My Arenas', _cyan,
              () => Get.toNamed(AppRoutes.myArenas)),
          const SizedBox(width: 10),
          _quickAction(Icons.assignment_outlined, 'Bookings', _greenFixed,
              () => Get.toNamed(AppRoutes.ownerBookings)),
          const SizedBox(width: 10),
          _quickAction(Icons.rocket_launch_outlined, 'Boost', _amber,
              () => Get.toNamed(AppRoutes.boostRequest)),
        ],
      ),
    );
  }

  Widget _quickAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _surfaceLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                    color: _onSurface, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(OwnerBookingController ownerBookings) {
    return Obx(() {
      final recent = ownerBookings.all.take(5).toList();
      if (recent.isEmpty) {
        return const Text('No recent bookings',
            style: TextStyle(color: _onSurfaceVar));
      }
      return Column(
        children: recent
            .map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _activityRow(b),
                ))
            .toList(),
      );
    });
  }

  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed:
      case BookingStatus.completed:
      case BookingStatus.refundConfirmed:
        return _greenFixed;
      case BookingStatus.rejected:
      case BookingStatus.cancelled:
        return _red;
      case BookingStatus.refundPending:
      case BookingStatus.refundSent:
        return _red;
      case BookingStatus.pendingDeposit:
      case BookingStatus.depositSubmitted:
        return _amber;
    }
  }

  IconData _statusIcon(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed:
      case BookingStatus.completed:
      case BookingStatus.refundConfirmed:
        return Icons.check;
      case BookingStatus.rejected:
      case BookingStatus.cancelled:
        return Icons.close;
      case BookingStatus.refundPending:
      case BookingStatus.refundSent:
        return Icons.replay;
      case BookingStatus.pendingDeposit:
      case BookingStatus.depositSubmitted:
        return Icons.hourglass_top;
    }
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    final hh = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final suffix = d.hour >= 12 ? 'PM' : 'AM';
    final time = '$hh:${d.minute.toString().padLeft(2, '0')} $suffix';
    if (diff == 0) return 'Today, $time';
    if (diff == 1) return 'Yesterday, $time';
    return '${d.day}/${d.month}, $time';
  }

  Widget _activityRow(BookingModel b) {
    final color = _statusColor(b.status);
    return Container(
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
              color: _surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_statusIcon(b.status), size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${b.courtName} booked by ${b.customerName.isNotEmpty ? b.customerName : 'Guest'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _onSurface, fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _dayLabel(b.startDateTime),
                  style: const TextStyle(color: _onSurfaceVar, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  b.status.label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
