import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/owner_booking_controller.dart';
import '../../../controllers/owner_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../data/models/arena_model.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/court_model.dart';
import '../../../data/models/pos_transaction_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

final _pkr = NumberFormat('#,##0');
final _timeFmt = DateFormat('hh:mm a');

// ── Breakpoints ──────────────────────────────────────────────────────────────
const double _kTablet = 600;
const double _kDesktop = 1024;

// ── Shell ────────────────────────────────────────────────────────────────────

class PosShellScreen extends StatefulWidget {
  const PosShellScreen({super.key});

  @override
  State<PosShellScreen> createState() => _PosShellScreenState();
}

class _PosShellScreenState extends State<PosShellScreen> {
  int _tab = 0; // 0=home 1=courts 2=bookings 3=transactions 4=more

  void _setTab(int t) => setState(() => _tab = t);

  void _ensureControllers() {
    if (!Get.isRegistered<OwnerController>()) Get.put(OwnerController());
    if (!Get.isRegistered<OwnerBookingController>()) {
      Get.put(OwnerBookingController(), permanent: true);
    }
    if (!Get.isRegistered<PosController>()) {
      Get.put(PosController(), permanent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureControllers();
    return LayoutBuilder(builder: (ctx, box) {
      final w = box.maxWidth;
      final isMobile = w < _kTablet;
      final isDesktop = w >= _kDesktop;

      final body = SafeArea(
        bottom: false,
        child: Row(children: [
          // Sidebar / nav rail
          if (!isMobile)
            _Sidebar(
              tab: _tab,
              expanded: isDesktop,
              onTab: _setTab,
            ),
          // Workspace + right panel
          Expanded(
            child: Column(children: [
              _TopBar(isMobile: isMobile),
              Expanded(
                child: Row(children: [
                  Expanded(
                    child: _TabContent(tab: _tab, isMobile: isMobile),
                  ),
                  if (!isMobile) const _RightPanel(),
                ]),
              ),
            ]),
          ),
        ]),
      );

      return Scaffold(
        backgroundColor: AppColors.background,
        body: body,
        bottomNavigationBar: isMobile
            ? _BottomNav(tab: _tab, onTab: _setTab)
            : null,
      );
    });
  }
}

// ── Sidebar ──────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final int tab;
  final bool expanded;
  final ValueChanged<int> onTab;

  const _Sidebar({required this.tab, required this.expanded, required this.onTab});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: expanded ? 220 : 68,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(children: [
        // Logo
        Container(
          height: 56,
          padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bolt, color: AppColors.onPrimary, size: 18),
              ),
              if (expanded) ...[
                const SizedBox(width: 10),
                Text('ArenaPro',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    )),
              ],
            ],
          ),
        ),
        // Nav items
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
            if (expanded) _sectionLabel('POS'),
            _navItem(Icons.speed_outlined, 'Dashboard', 0),
            _navItem(Icons.stadium_outlined, 'Live Courts', 1),
            _navItem(Icons.add_circle_outline, 'New Walk-in', -1, isAction: true),
            if (expanded) _sectionLabel('Manage'),
            _navItem(Icons.calendar_today_outlined, 'Bookings', 2),
            _navItem(Icons.receipt_long_outlined, 'Transactions', 3),
            _navItem(Icons.money_off_outlined, 'Expenses', 4, subRoute: AppRoutes.posExpenses),
            _navItem(Icons.bar_chart_outlined, 'Reports', 5, subRoute: AppRoutes.posReports),
            _navItem(Icons.storefront_outlined, 'Products', 6, subRoute: AppRoutes.posProducts),
          ]),
        ),
        // Shift + bottom items
        const Divider(color: AppColors.border, height: 1),
        _ShiftChip(expanded: expanded),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: Text(label.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textDisabled,
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            )),
      );

  Widget _navItem(IconData icon, String label, int t,
      {bool isAction = false, String? subRoute}) {
    final active = t == tab && t >= 0;
    return GestureDetector(
      onTap: () {
        if (subRoute != null) { Get.toNamed(subRoute); return; }
        if (t == -1) { Get.toNamed(AppRoutes.posWalkIn); return; }
        onTab(t);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isAction
              ? AppColors.success.withValues(alpha: 0.10)
              : active
                  ? AppColors.primary.withValues(alpha: 0.10)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isAction
              ? Border.all(color: AppColors.success.withValues(alpha: 0.2))
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isAction
                    ? AppColors.success
                    : active
                        ? AppColors.primary
                        : AppColors.textSecondary,
                size: 20),
            if (expanded) ...[
              const SizedBox(width: 10),
              Text(label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isAction
                        ? AppColors.success
                        : active
                            ? AppColors.primary
                            : AppColors.textSecondary,
                    fontWeight: active || isAction ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShiftChip extends StatelessWidget {
  final bool expanded;
  const _ShiftChip({required this.expanded});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pos = PosController.to;
      final shift = pos.openShift.value;
      return GestureDetector(
        onTap: () => Get.toNamed(AppRoutes.posShift),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: shift != null
                ? AppColors.success.withValues(alpha: 0.10)
                : AppColors.elevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: shift != null
                  ? AppColors.success.withValues(alpha: 0.25)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(Icons.circle,
                  color: shift != null ? AppColors.success : AppColors.textDisabled,
                  size: 8),
              if (expanded) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shift != null ? 'Shift Open' : 'No Shift',
                    style: AppTextStyles.caption.copyWith(
                      color: shift != null ? AppColors.success : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

// ── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool isMobile;
  const _TopBar({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        if (isMobile) ...[
          GestureDetector(
            onTap: Get.back,
            child: const Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('POS',
                  style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
              Obx(() {
                final name = PosController.to.selectedArena.value?.name ?? '';
                return Text(name,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary));
              }),
            ],
          ),
        ] else ...[
          Obx(() {
            final arena = PosController.to.selectedArena.value;
            return Row(children: [
              Text(arena?.name ?? 'POS',
                  style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(DateFormat('EEE, d MMM').format(DateTime.now()),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ),
            ]);
          }),
        ],
        const Spacer(),
        // Arena selector
        Obx(() {
          final arenas = OwnerController.to.myArenas;
          if (arenas.length <= 1) return const SizedBox.shrink();
          return _topBtn(Icons.swap_horiz, () => _showArenaSelector(arenas));
        }),
        const SizedBox(width: 8),
        _topBtn(Icons.notifications_outlined, () {}),
        const SizedBox(width: 8),
        // Profile chip
        if (!isMobile)
          Obx(() {
            final user = AuthController.to.currentUser.value;
            final name = user?.name ?? '';
            final initials = name.isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
            return Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(initials,
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11)),
                ),
                const SizedBox(width: 6),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.split(' ').first,
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                    Text('Owner',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary, fontSize: 10)),
                  ],
                ),
              ]),
            );
          }),
      ]),
    );
  }

  Widget _topBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 19),
        ),
      );

  void _showArenaSelector(List<ArenaModel> arenas) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Select Arena',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...arenas.map((a) => ListTile(
                title: Text(a.name, style: AppTextStyles.bodyMedium),
                subtitle: Text(a.location.address,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                trailing: Obx(() => PosController.to.selectedArena.value?.id == a.id
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : const SizedBox.shrink()),
                onTap: () { PosController.to.selectArena(a); Get.back(); },
              )),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

// ── Tab Content ───────────────────────────────────────────────────────────────

class _TabContent extends StatelessWidget {
  final int tab;
  final bool isMobile;
  const _TabContent({required this.tab, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return IndexedStack(index: tab, children: [
      _HomeTab(isMobile: isMobile),
      const _CourtsTab(),
      const _BookingsTab(),
      const _TransactionsTab(),
      const _MoreTab(),
    ]);
  }
}

// ── HOME TAB ─────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  final bool isMobile;
  const _HomeTab({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: PosController.to.refreshStats,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 20, 16,
          isMobile ? 12 : 20, 80,
        ),
        children: [
          // Greeting
          Text(
            _greeting(),
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: isMobile ? 20 : 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          // KPI grid
          _KpiGrid(isMobile: isMobile),
          const SizedBox(height: 20),
          // Primary CTA - Walk-in
          _WalkInCta(),
          const SizedBox(height: 12),
          // Quick actions row
          _QuickActionsRow(isMobile: isMobile),
          const SizedBox(height: 20),
          // Today's bookings
          _TodaySection(),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    final name = AuthController.to.currentUser.value?.name.split(' ').first ?? '';
    if (h < 12) return 'Good Morning${name.isNotEmpty ? ", $name" : ""} 👋';
    if (h < 17) return 'Good Afternoon${name.isNotEmpty ? ", $name" : ""} 👋';
    return 'Good Evening${name.isNotEmpty ? ", $name" : ""} 👋';
  }
}

class _KpiGrid extends StatelessWidget {
  final bool isMobile;
  const _KpiGrid({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pos = PosController.to;
      final now = DateTime.now();
      final all = OwnerBookingController.to.all;
      final todayBk = all.where((b) =>
          b.date.year == now.year &&
          b.date.month == now.month &&
          b.date.day == now.day &&
          !b.isCancelled).length;
      final courts = pos.selectedArena.value?.courts ?? [];
      final available = courts.where((c) =>
          pos.courtStatus(c.id) == CourtLiveStatus.available).length;

      final kpis = [
        _Kpi('Revenue', 'PKR ${_pkr.format(pos.todayRevenue.value)}',
            AppColors.primary, Icons.attach_money_rounded, '+12%'),
        _Kpi('Walk-ins', 'PKR ${_pkr.format(pos.todayPaid.value)}',
            AppColors.success, Icons.directions_walk, '+5%'),
        _Kpi('Bookings', '$todayBk',
            AppColors.accent, Icons.calendar_month_outlined, null),
        _Kpi('Available', '$available Courts',
            AppColors.secondary, Icons.stadium_outlined, null),
      ];

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isMobile ? 2 : 4,
          childAspectRatio: isMobile ? 1.55 : 1.6,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: kpis.length,
        itemBuilder: (_, i) => _KpiCard(kpi: kpis[i]),
      );
    });
  }
}

class _Kpi {
  final String label, value;
  final Color color;
  final IconData icon;
  final String? trend;
  const _Kpi(this.label, this.value, this.color, this.icon, this.trend);
}

class _KpiCard extends StatelessWidget {
  final _Kpi kpi;
  const _KpiCard({required this.kpi});

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
        children: [
          // Top border via colored left accent line approach
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: kpi.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(kpi.icon, color: kpi.color, size: 15),
            ),
            const Spacer(),
            if (kpi.trend != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(kpi.trend!,
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.success,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
          ]),
          const Spacer(),
          Text(kpi.value,
              style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(kpi.label,
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _WalkInCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.posWalkIn),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.success, AppColors.success.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: Color(0xFF0A1A06), size: 22),
            SizedBox(width: 8),
            Text('New Walk-in',
                style: TextStyle(
                    color: Color(0xFF0A1A06),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final bool isMobile;
  const _QuickActionsRow({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QA('Court View', Icons.stadium_outlined, AppColors.primary, () => Get.toNamed(AppRoutes.posLiveCourts)),
      _QA('Transactions', Icons.receipt_long_outlined, AppColors.accent, () => Get.toNamed(AppRoutes.posTransactions)),
      _QA('Expenses', Icons.money_off_outlined, AppColors.warning, () => Get.toNamed(AppRoutes.posExpenses)),
      _QA('Reports', Icons.bar_chart_outlined, AppColors.secondary, () => Get.toNamed(AppRoutes.posReports)),
      _QA('Shift', Icons.access_time_outlined, AppColors.textSecondary, () => Get.toNamed(AppRoutes.posShift)),
      _QA('Products', Icons.storefront_outlined, AppColors.error, () => Get.toNamed(AppRoutes.posProducts)),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 3 : 6,
        childAspectRatio: 0.95,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: actions.length,
      itemBuilder: (_, i) {
        final a = actions[i];
        return GestureDetector(
          onTap: a.onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(a.icon, color: a.color, size: 20),
              ),
              const SizedBox(height: 7),
              Text(a.label,
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 10),
                  textAlign: TextAlign.center,
                  maxLines: 2),
            ]),
          ),
        );
      },
    );
  }
}

class _QA {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QA(this.label, this.icon, this.color, this.onTap);
}

class _TodaySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final now = DateTime.now();
      final all = OwnerBookingController.to.all;
      final today = all
          .where((b) =>
              b.date.year == now.year &&
              b.date.month == now.month &&
              b.date.day == now.day &&
              !b.isCancelled)
          .toList()
        ..sort((a, b) => a.startHour.compareTo(b.startHour));

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text("Today's Bookings",
              style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text('${today.length}',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 12),
        if (today.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No bookings today',
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary)),
            ),
          )
        else
          ...today.map((b) => _BookingRow(booking: b)),
      ]);
    });
  }
}

class _BookingRow extends StatelessWidget {
  final BookingModel booking;
  const _BookingRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isNow = booking.startHour <= now.hour &&
        now.hour < booking.startHour + booking.totalHours;
    final isPast = booking.endDateTime.isBefore(now);
    final color = isNow
        ? AppColors.success
        : isPast
            ? AppColors.textDisabled
            : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: isNow
            ? [BoxShadow(color: AppColors.success.withValues(alpha: 0.08), blurRadius: 8)]
            : null,
      ),
      child: Row(children: [
        Container(width: 3, height: 40,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(booking.timeRange,
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 10)),
          Text(booking.courtName,
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ])),
        Text(
          booking.customerName.isNotEmpty ? booking.customerName : 'Walk-in',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isNow ? 'LIVE' : isPast ? 'Done' : booking.status.label,
            style: AppTextStyles.caption.copyWith(
                color: color, fontWeight: FontWeight.w700, fontSize: 10),
          ),
        ),
      ]),
    );
  }
}

// ── COURTS TAB ───────────────────────────────────────────────────────────────

class _CourtsTab extends StatelessWidget {
  const _CourtsTab();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pos = PosController.to;
      final arena = pos.selectedArena.value;
      final courts = arena?.courts ?? [];

      return RefreshIndicator(
        onRefresh: pos.refreshStats,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                Text('Live Courts',
                    style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                  ),
                  child: Text('${courts.length} Courts',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 10)),
                ),
              ]),
            ),
          ),
          if (courts.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('No courts configured',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 380,
                  childAspectRatio: 2.8,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _CourtCard(court: courts[i]),
                  childCount: courts.length,
                ),
              ),
            ),
        ]),
      );
    });
  }
}

class _CourtCard extends StatelessWidget {
  final CourtModel court;
  const _CourtCard({required this.court});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pos = PosController.to;
      final status = pos.courtStatus(court.id);
      final isAvailable = status == CourtLiveStatus.available;
      final isOccupied = status == CourtLiveStatus.occupied;
      final color = isAvailable
          ? AppColors.success
          : isOccupied
              ? AppColors.warning
              : AppColors.primary;
      final currentBk = isOccupied ? pos.currentBookingForCourt(court.id) : null;

      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          // Colored left accent strip
          Container(
            width: 4,
            height: double.infinity,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(court.name,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700)),
                Text(court.type.label,
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary, fontSize: 11)),
                if (currentBk != null)
                  Text(
                    '${currentBk.timeRange} · ${currentBk.customerName.isNotEmpty ? currentBk.customerName : "Walk-in"}',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isAvailable ? 'Available' : isOccupied ? 'Occupied' : 'Upcoming',
              style: AppTextStyles.caption.copyWith(
                  color: color, fontWeight: FontWeight.w700, fontSize: 10),
            ),
          ),
          if (isAvailable)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => Get.toNamed(AppRoutes.posWalkIn,
                    arguments: {'courtId': court.id}),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Book',
                      style: AppTextStyles.caption.copyWith(
                          color: const Color(0xFF0A1A06),
                          fontWeight: FontWeight.w700,
                          fontSize: 11)),
                ),
              ),
            ),
        ]),
      );
    });
  }
}

// ── BOOKINGS TAB ─────────────────────────────────────────────────────────────

class _BookingsTab extends StatelessWidget {
  const _BookingsTab();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final now = DateTime.now();
      final all = OwnerBookingController.to.all;
      final today = all
          .where((b) =>
              b.date.year == now.year &&
              b.date.month == now.month &&
              b.date.day == now.day &&
              !b.isCancelled)
          .toList()
        ..sort((a, b) => a.startHour.compareTo(b.startHour));

      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: today.isEmpty ? 1 : today.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(children: [
                Text("Today's Bookings",
                    style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('${today.length} total',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
              ]),
            );
          }
          if (today.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text('No bookings today',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            );
          }
          final b = today[i - 1];
          return _BookingTimelineItem(booking: b, isLast: i == today.length);
        },
      );
    });
  }
}

class _BookingTimelineItem extends StatelessWidget {
  final BookingModel booking;
  final bool isLast;
  const _BookingTimelineItem({required this.booking, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isNow = booking.startHour <= now.hour &&
        now.hour < booking.startHour + booking.totalHours;
    final isPast = booking.endDateTime.isBefore(now);
    final color = isNow
        ? AppColors.success
        : isPast
            ? AppColors.textDisabled
            : AppColors.primary;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Timeline
        SizedBox(
          width: 56,
          child: Column(children: [
            Text(
              TimeOfDay(hour: booking.startHour, minute: 0).format(context),
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary, fontSize: 10),
              textAlign: TextAlign.right,
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Column(children: [
          const SizedBox(height: 4),
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          if (!isLast)
            Expanded(child: Container(width: 1, color: AppColors.border)),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => Get.toNamed(AppRoutes.bookingDetailOwner,
                  arguments: booking),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isNow
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.border),
                ),
                child: Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(booking.courtName,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${booking.customerName.isNotEmpty ? booking.customerName : "Walk-in"} · ${booking.isPosBooking ? "Walk-in" : "Online"}',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isNow ? 'LIVE' : isPast ? 'Done' : booking.status.label,
                        style: AppTextStyles.caption.copyWith(
                            color: color, fontWeight: FontWeight.w700, fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PKR ${_pkr.format(booking.isPosBooking ? (booking.amountPaid ?? 0) : booking.depositAmount)}',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 11),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── TRANSACTIONS TAB ─────────────────────────────────────────────────────────

class _TransactionsTab extends StatefulWidget {
  const _TransactionsTab();

  @override
  State<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<_TransactionsTab> {
  String _search = '';
  PosPaymentMethod? _method;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Search
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search by customer or court…',
            hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textDisabled),
            prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 18),
            filled: true,
            fillColor: AppColors.elevated,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
      ),
      // Method filter chips
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip('All', _method == null, () => setState(() => _method = null)),
            ...PosPaymentMethod.values.map((m) => _chip(
                  m.label, _method == m,
                  () => setState(() => _method = _method == m ? null : m))),
          ]),
        ),
      ),
      // List
      Expanded(
        child: Obx(() {
          final all = PosController.to.transactions;
          final filtered = all.where((t) {
            if (_search.isNotEmpty &&
                !t.customerName.toLowerCase().contains(_search.toLowerCase()) &&
                !(t.courtName ?? '').toLowerCase().contains(_search.toLowerCase())) {
              return false;
            }
            if (_method != null && t.paymentMethod != _method) return false;
            return true;
          }).toList();

          if (filtered.isEmpty) {
            return const Center(
              child: Text('No transactions',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }

          final totalPaid = filtered.fold(0.0, (s, t) => s + t.amountPaid);
          final totalPending = filtered.fold(0.0, (s, t) => s + t.remainingAmount);

          return Column(children: [
            // Summary bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.elevated,
              child: Row(children: [
                Text('${filtered.length} transactions',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('Paid: PKR ${_pkr.format(totalPaid)}',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.success, fontWeight: FontWeight.w600)),
                if (totalPending > 0) ...[
                  const SizedBox(width: 12),
                  Text('Pending: PKR ${_pkr.format(totalPending)}',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.warning, fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _TxnCard(txn: filtered[i]),
              ),
            ),
          ]);
        }),
      ),
    ]);
  }

  Widget _chip(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withValues(alpha: 0.12) : AppColors.elevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: active ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
          ),
          child: Text(label,
              style: AppTextStyles.caption.copyWith(
                  color: active ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        ),
      );
}

class _TxnCard extends StatelessWidget {
  final PosTransactionModel txn;
  const _TxnCard({required this.txn});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Center(
            child: Text(
              txn.customerName.isNotEmpty
                  ? txn.customerName[0].toUpperCase()
                  : '?',
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            txn.customerName.isNotEmpty ? txn.customerName : 'Walk-in',
            style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          Text(
            '${txn.courtName ?? txn.arenaName} · ${_timeFmt.format(txn.createdAt)} · ${txn.paymentMethod.label}',
            style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary, fontSize: 10),
          ),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('PKR ${_pkr.format(txn.amountPaid)}',
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.success, fontWeight: FontWeight.w700)),
          if (txn.remainingAmount > 0)
            Text('Bal: ${_pkr.format(txn.remainingAmount)}',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

// ── MORE TAB ─────────────────────────────────────────────────────────────────

class _MoreTab extends StatelessWidget {
  const _MoreTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        Text('More',
            style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        const SizedBox(height: 16),
        // Shift card
        Obx(() {
          final pos = PosController.to;
          final shift = pos.openShift.value;
          return GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.posShift),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: shift != null
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: shift != null
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.border,
                ),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: (shift != null ? AppColors.success : AppColors.textSecondary)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.access_time_outlined,
                      color: shift != null ? AppColors.success : AppColors.textSecondary,
                      size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(shift != null ? 'Shift Open' : 'No Active Shift',
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                  Text(
                    shift != null
                        ? 'Tap to view or close shift'
                        : 'Tap to open a new shift',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ])),
                Icon(
                  Icons.circle,
                  color: shift != null ? AppColors.success : AppColors.error,
                  size: 10,
                ),
              ]),
            ),
          );
        }),
        ...[
          _MoreItem('Expenses', Icons.money_off_outlined, AppColors.warning,
              'Track operating costs', () => Get.toNamed(AppRoutes.posExpenses)),
          _MoreItem('Reports', Icons.bar_chart_outlined, AppColors.secondary,
              'Revenue and analytics', () => Get.toNamed(AppRoutes.posReports)),
          _MoreItem('Products', Icons.storefront_outlined, AppColors.accent,
              'Manage add-ons and products', () => Get.toNamed(AppRoutes.posProducts)),
        ].map((m) => GestureDetector(
          onTap: m.onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(m.icon, color: m.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                Text(m.subtitle,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ])),
              const Icon(Icons.chevron_right, color: AppColors.textDisabled, size: 20),
            ]),
          ),
        )),
      ],
    );
  }
}

class _MoreItem {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MoreItem(this.title, this.icon, this.color, this.subtitle, this.onTap);
}

// ── RIGHT PANEL ───────────────────────────────────────────────────────────────

class _RightPanel extends StatelessWidget {
  const _RightPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(children: [
        // Panel header
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Text('ORDER',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.textDisabled,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.5)),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(14), children: [
            // Today's stats
            _PanelStatsCard(),
            const SizedBox(height: 12),
            // New walk-in CTA
            GestureDetector(
              onTap: () => Get.toNamed(AppRoutes.posWalkIn),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.2),
                        blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Color(0xFF0A1A06), size: 18),
                    SizedBox(width: 6),
                    Text('New Walk-in',
                        style: TextStyle(
                            color: Color(0xFF0A1A06),
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Recent transactions
            Text('Recent',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.textDisabled,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    letterSpacing: 1.2)),
            const SizedBox(height: 8),
            _PanelRecentTxns(),
          ]),
        ),
      ]),
    );
  }
}

class _PanelStatsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pos = PosController.to;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          _panelRow('Today Revenue',
              'PKR ${_pkr.format(pos.todayRevenue.value)}', AppColors.primary),
          const Divider(color: AppColors.border, height: 16),
          _panelRow('Paid',
              'PKR ${_pkr.format(pos.todayPaid.value)}', AppColors.success),
          const SizedBox(height: 6),
          _panelRow('Pending',
              'PKR ${_pkr.format(pos.todayRemaining.value)}', AppColors.warning),
          const SizedBox(height: 6),
          _panelRow('Expenses',
              'PKR ${_pkr.format(pos.todayExpenses.value)}', AppColors.error),
        ]),
      );
    });
  }

  Widget _panelRow(String label, String value, Color color) => Row(
        children: [
          Text(label,
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary, fontSize: 11)),
          const Spacer(),
          Text(value,
              style: AppTextStyles.caption.copyWith(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      );
}

class _PanelRecentTxns extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final txns = PosController.to.transactions.take(5).toList();
      if (txns.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('No transactions yet',
                style: AppTextStyles.caption.copyWith(color: AppColors.textDisabled)),
          ),
        );
      }
      return Column(
        children: txns
            .map((t) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          t.customerName.isNotEmpty ? t.customerName[0].toUpperCase() : '?',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        t.customerName.isNotEmpty ? t.customerName : 'Walk-in',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(t.courtName ?? '',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary, fontSize: 9)),
                    ])),
                    Text('PKR ${_pkr.format(t.amountPaid)}',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 11)),
                  ]),
                ))
            .toList(),
      );
    });
  }
}

// ── BOTTOM NAV (mobile) ───────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTab;
  const _BottomNav({required this.tab, required this.onTab});

  @override
  Widget build(BuildContext context) {
    const items = [
      _BnItem(Icons.speed_outlined, Icons.speed, 'POS'),
      _BnItem(Icons.calendar_today_outlined, Icons.calendar_today, 'Bookings'),
      _BnItem(Icons.stadium_outlined, Icons.stadium, 'Courts'),
      _BnItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Txns'),
      _BnItem(Icons.more_horiz, Icons.more_horiz, 'More'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final active = tab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTab(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active ? item.activeIcon : item.icon,
                        color: active ? AppColors.primary : AppColors.textDisabled,
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(item.label,
                          style: AppTextStyles.caption.copyWith(
                              color: active ? AppColors.primary : AppColors.textDisabled,
                              fontSize: 9,
                              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                              letterSpacing: 0.3)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _BnItem {
  final IconData icon, activeIcon;
  final String label;
  const _BnItem(this.icon, this.activeIcon, this.label);
}
