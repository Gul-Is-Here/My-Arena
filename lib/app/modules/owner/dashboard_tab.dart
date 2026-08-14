import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../controllers/owner_booking_controller.dart';
import '../../controllers/owner_controller.dart';
import '../../data/models/booking_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

const _bg = AppColors.background;
const _surface = AppColors.surface;
const _surfaceLow = AppColors.elevated;
const _outline = AppColors.border;
const _cyan = AppColors.secondary;
const _greenFixed = AppColors.success;
const _amber = AppColors.warning;
const _red = AppColors.error;
const _onSurface = AppColors.textPrimary;
const _onSurfaceVar = AppColors.textSecondary;

// Breakpoints (must match owner_dashboard_screen.dart)
const _kTablet = 720.0;
const _kDesktop = 1100.0;
// Max content width on desktop so it doesn't stretch to 1600px
const _kMaxContent = 1280.0;

final _pkr = NumberFormat('#,##0');

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
    if (!Get.isRegistered<OwnerController>()) {
      Get.put(OwnerController());
    }
    final owner = OwnerController.to;
    if (!Get.isRegistered<OwnerBookingController>()) {
      Get.put(OwnerBookingController(), permanent: true);
    }
    final ownerBookings = OwnerBookingController.to;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isTablet = w >= _kTablet;
        final isDesktop = w >= _kDesktop;

        // Horizontal padding: tighter on mobile, more breathing room on wide
        final hPad = isDesktop
            ? 32.0
            : isTablet
            ? 24.0
            : 16.0;
        // Bottom padding: no extendBody offset on wide (no bottom nav)
        final bPad = isTablet ? 32.0 : 96.0;

        return Container(
          color: _bg,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxContent),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(hPad, 20, hPad, bPad),
                  children: [
                    _buildHeader(isTablet),
                    const SizedBox(height: 24),

                    // ── Stat cards grid ──────────────────────────────
                    _buildStatGrid(ownerBookings, isTablet, isDesktop),
                    const SizedBox(height: 20),

                    // ── Revenue + Quick Actions (side-by-side on desktop)
                    if (isDesktop)
                      _buildDesktopMiddleRow(owner, ownerBookings)
                    else ...[
                      _buildRevenueCard(owner, ownerBookings, isTablet),
                      const SizedBox(height: 20),
                      Row(children: [
                        Text(
                          'Quick Actions',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: _onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _buildQuickActions(isTablet),
                    ],

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Activity',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: _onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Get.toNamed(AppRoutes.ownerBookings),
                          child: Text(
                            'See all',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildRecentActivity(ownerBookings, isTablet),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isTablet) {
    final user = AuthController.to.currentUser;
    return Obx(() {
      final u = user.value;
      final firstName = u?.name.isNotEmpty == true
          ? u!.name.split(' ').first
          : 'there';
      final now = DateTime.now();
      final dateStr =
          '${_weekday(now.weekday)}, ${now.day} ${_month(now.month)}';

      return Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surface,
              AppColors.elevated,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _greenFixed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                              color: _greenFixed.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: _greenFixed, shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'ARENA ONLINE',
                              style: AppTextStyles.caption.copyWith(
                                color: _greenFixed,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          '${_greeting()}, $firstName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleLarge.copyWith(
                            color: _onSurface,
                            fontSize: isTablet ? 26 : 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('👋', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: _onSurfaceVar,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Obx(() {
                  final unread = NotificationController.to.unreadCount;
                  return GestureDetector(
                    onTap: () => Get.toNamed(AppRoutes.notifications),
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _onSurface.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _outline),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: _onSurfaceVar,
                          size: 20,
                        ),
                      ),
                      if (unread > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: _amber,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                  color: _bg, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                unread > 9 ? '9+' : '$unread',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  );
                }),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => Get.toNamed(AppRoutes.posDashboard),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2ae500), Color(0xFF00dbe9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.point_of_sale_rounded,
                            color: Colors.black, size: 14),
                        SizedBox(width: 5),
                        Text(
                          'POS',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  String _weekday(int d) => const [
        '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
      ][d];

  String _month(int m) => const [
        '',
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  // ── Stat grid — 2 cols mobile, 4 cols tablet/desktop ─────────────────────

  Widget _buildStatGrid(
    OwnerBookingController ownerBookings,
    bool isTablet,
    bool isDesktop,
  ) {
    final cols = isTablet ? 4 : 2;
    final ratio = isDesktop
        ? 1.6
        : isTablet
        ? 1.5
        : 1.45;

    return Obx(() {
      final today = DateTime.now();
      final bookingsToday = ownerBookings.all
          .where((b) => _isSameDay(b.date, today))
          .length;
      final pendingCount = ownerBookings.pendingApproval.length;
      final totalEarnings = ownerBookings.all
          .where(
            (b) =>
                b.status == BookingStatus.confirmed ||
                b.status == BookingStatus.completed,
          )
          .fold(0.0, (acc, b) => acc + b.totalAmount);
      final todayCash = ownerBookings.all
          .where(
            (b) =>
                _isSameDay(b.date, today) &&
                b.bookedByRole == 'owner' &&
                (b.status == BookingStatus.confirmed ||
                    b.status == BookingStatus.completed),
          )
          .fold(0.0, (acc, b) => acc + b.totalAmount);

      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: ratio,
        children: [
          _statCard(
            icon: Icons.payments_outlined,
            iconColor: _greenFixed,
            label: 'Total Earnings',
            value: 'PKR ${_pkr.format(totalEarnings)}',
            onTap: () => Get.toNamed(AppRoutes.ownerEarnings),
          ),
          _statCard(
            icon: Icons.point_of_sale_outlined,
            iconColor: _amber,
            label: "Today's Walk-ins",
            value: 'PKR ${_pkr.format(todayCash)}',
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
            icon: Icons.hourglass_top_outlined,
            iconColor: _red,
            label: 'Pending Approvals',
            value: '$pendingCount',
            badge: pendingCount > 0 ? 'ACTION NEEDED' : null,
            onTap: () => Get.toNamed(AppRoutes.ownerBookings),
          ),
        ],
      );
    });
  }

  // ── Desktop two-column middle section (revenue | quick actions) ───────────

  Widget _buildDesktopMiddleRow(
    OwnerController owner,
    OwnerBookingController ownerBookings,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: _buildRevenueCard(owner, ownerBookings, true),
          ),
          const SizedBox(width: 20),
          SizedBox(width: 240, child: _buildDesktopQuickActionsPanel()),
        ],
      ),
    );
  }

  Widget _buildDesktopQuickActionsPanel() {
    final actions = [
      _QA(
        Icons.point_of_sale_outlined,
        'POS',
        AppColors.primary,
        () => Get.toNamed(AppRoutes.posDashboard),
      ),
      _QA(
        Icons.stadium_outlined,
        'My Arenas',
        AppColors.primary,
        () => Get.toNamed(AppRoutes.myArenas),
      ),
      _QA(
        Icons.assignment_outlined,
        'Bookings',
        _greenFixed,
        () => Get.toNamed(AppRoutes.ownerBookings),
      ),
      _QA(
        Icons.calendar_view_week_outlined,
        'Schedule',
        _onSurfaceVar,
        () => Get.toNamed(AppRoutes.ownerSchedule),
      ),
      _QA(
        Icons.rocket_launch_outlined,
        'Boost',
        _amber,
        () => Get.toNamed(AppRoutes.boostRequest),
      ),
      _QA(
        Icons.group_outlined,
        'My Team',
        AppColors.secondary,
        () => OwnerController.to.shellTab.value = 3,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: AppTextStyles.titleMedium.copyWith(
              color: _onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              children: [
                for (final a in actions) ...[
                  _desktopActionRow(a),
                  if (a != actions.last) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopActionRow(_QA a) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: a.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _outline),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(a.icon, size: 16, color: a.color),
              ),
              const SizedBox(width: 10),
              Text(
                a.label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: _onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, size: 16, color: _onSurfaceVar),
            ],
          ),
        ),
      ),
    );
  }

  // ── Revenue card ───────────────────────────────────────────────────────────

  Widget _buildRevenueCard(
    OwnerController owner,
    OwnerBookingController ownerBookings,
    bool isTablet,
  ) {
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
                Expanded(
                  child: Text(
                    'Revenue Overview',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: _onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'PKR ${_pkr.format(total)}',
                  style: AppTextStyles.scoreboard.copyWith(
                    color: _greenFixed,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
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
            height: isTablet ? 240 : 200,
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
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
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
                              style: AppTextStyles.caption.copyWith(
                                color: _onSurfaceVar,
                                fontSize: 11,
                              ),
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
                      getTooltipItems: (spots) => spots
                          .map(
                            (s) => LineTooltipItem(
                              'PKR ${_pkr.format(s.y)}',
                              AppTextStyles.bodySmall.copyWith(
                                color: _greenFixed,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i]),
                      ],
                      isCurved: true,
                      curveSmoothness: 0.35,
                      barWidth: 2.5,
                      color: _greenFixed,
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, data) =>
                            spot.x == data.spots.last.x,
                        getDotPainter: (spot, pct, data, i) =>
                            FlDotCirclePainter(
                              radius: 5,
                              color: _greenFixed,
                              strokeColor: _bg,
                              strokeWidth: 2,
                            ),
                      ),
                      shadow: Shadow(
                        color: _greenFixed.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _greenFixed.withValues(alpha: 0.20),
                            _greenFixed.withValues(alpha: 0.0),
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
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: selected ? AppColors.primary : _onSurfaceVar,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ── Quick actions: 3-col grid on mobile, scroll row on tablet ────────────

  Widget _buildQuickActions(bool isTablet) {
    final actions = [
      _QA(Icons.point_of_sale_rounded, 'POS', AppColors.primary,
          () => Get.toNamed(AppRoutes.posDashboard)),
      _QA(Icons.stadium_rounded, 'My Arenas', AppColors.primary,
          () => Get.toNamed(AppRoutes.myArenas)),
      _QA(Icons.assignment_rounded, 'Bookings', _greenFixed,
          () => Get.toNamed(AppRoutes.ownerBookings)),
      _QA(Icons.calendar_view_week_rounded, 'Schedule', _cyan,
          () => Get.toNamed(AppRoutes.ownerSchedule)),
      _QA(Icons.rocket_launch_rounded, 'Boost', _amber,
          () => Get.toNamed(AppRoutes.boostRequest)),
      _QA(Icons.group_rounded, 'My Team', AppColors.secondary,
          () => OwnerController.to.shellTab.value = 3),
    ];

    if (isTablet) {
      return SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (int i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              _quickActionChip(actions[i]),
            ],
          ],
        ),
      );
    }

    // Mobile: 3-column grid
    return Column(
      children: [
        Row(children: [
          Expanded(child: _quickActionTile(actions[0])),
          const SizedBox(width: 10),
          Expanded(child: _quickActionTile(actions[1])),
          const SizedBox(width: 10),
          Expanded(child: _quickActionTile(actions[2])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _quickActionTile(actions[3])),
          const SizedBox(width: 10),
          Expanded(child: _quickActionTile(actions[4])),
          const SizedBox(width: 10),
          Expanded(child: _quickActionTile(actions[5])),
        ]),
      ],
    );
  }

  Widget _quickActionTile(_QA a) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: a.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: a.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: a.color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(a.icon, size: 19, color: a.color),
              ),
              const SizedBox(height: 7),
              Text(
                a.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActionChip(_QA a) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: a.onTap,
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
              Icon(a.icon, size: 18, color: a.color),
              const SizedBox(width: 8),
              Text(
                a.label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: _onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Recent activity ────────────────────────────────────────────────────────

  Widget _buildRecentActivity(
    OwnerBookingController ownerBookings,
    bool isTablet,
  ) {
    return Obx(() {
      final recent = ownerBookings.all.take(isTablet ? 8 : 5).toList();
      if (recent.isEmpty) {
        return Text(
          'No recent bookings',
          style: AppTextStyles.bodyMedium.copyWith(color: _onSurfaceVar),
        );
      }
      return Column(
        children: recent
            .map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _activityRow(b),
              ),
            )
            .toList(),
      );
    });
  }

  // ── Stat card ─────────────────────────────────────────────────────────────

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
          decoration: BoxDecoration(
            color: _surfaceLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outline),
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colored top accent bar
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: iconColor, size: 17),
                          ),
                          if (badge != null) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: _amber.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _amber.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                badge,
                                style: AppTextStyles.caption.copyWith(
                                  color: _amber,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
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
                            label.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: _onSurfaceVar,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              value,
                              style: AppTextStyles.headlineMedium.copyWith(
                                color: _onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Activity row ──────────────────────────────────────────────────────────

  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed:
      case BookingStatus.completed:
      case BookingStatus.refundConfirmed:
      case BookingStatus.ongoing:
        return _greenFixed;
      case BookingStatus.rejected:
      case BookingStatus.cancelled:
      case BookingStatus.refundPending:
      case BookingStatus.refundSent:
        return _red;
      case BookingStatus.pendingDeposit:
      case BookingStatus.depositSubmitted:
      case BookingStatus.rescheduleRequested:
        return _amber;
    }
  }

  IconData _statusIcon(BookingStatus s) {
    switch (s) {
      case BookingStatus.ongoing:
        return Icons.sports_outlined;
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
      case BookingStatus.rescheduleRequested:
        return Icons.edit_calendar_outlined;
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
    final isWalkIn = b.bookedByRole == 'owner';
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.bookingDetailOwner, arguments: b.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surfaceLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(_statusIcon(b.status), size: 19, color: color),
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
                          b.customerName.isNotEmpty ? b.customerName : 'Guest',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _onSurface,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isWalkIn
                              ? _amber.withValues(alpha: 0.14)
                              : _cyan.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          isWalkIn ? 'Walk-in' : 'Online',
                          style: TextStyle(
                            color: isWalkIn ? _amber : _cyan,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${b.courtName} · ${_dayLabel(b.startDateTime)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: _onSurfaceVar,
                      fontSize: 11.5,
                    ),
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
                  style: TextStyle(
                    color: _greenFixed,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        b.status.label,
                        style: AppTextStyles.caption.copyWith(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Quick action data class
class _QA {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QA(this.icon, this.label, this.color, this.onTap);
}
