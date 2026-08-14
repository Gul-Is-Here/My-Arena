import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../controllers/analytics_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/ticket_controller.dart';
import '../../controllers/tournament_controller.dart';
import '../../data/enums/permission.dart';
import '../../routes/app_routes.dart';
import '../../services/permission_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'admin_arenas_screen.dart';
import 'admin_chats_screen.dart';
import 'admin_tickets_screen.dart';

/// Admin shell — responsive: bottom nav on phone, NavigationRail on tablet/iPad.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AdminController>()) {
      Get.put(AdminController(), permanent: true);
    }
    if (!Get.isRegistered<TournamentController>()) {
      Get.put(TournamentController(), permanent: true);
    }
    if (!Get.isRegistered<TicketController>()) {
      Get.put(TicketController(), permanent: true);
    }
    if (!Get.isRegistered<AnalyticsController>()) {
      Get.put(AnalyticsController(), permanent: true);
    }

    final RxInt tab = 0.obs;

    final tabs = <Widget>[
      const _AdminHomeTab(),
      _PermGate(Permission.viewArenas, const AdminArenasScreen()),
      _PermGate(Permission.viewAllTickets, const AdminTicketsScreen()),
      _PermGate(Permission.viewAllTickets, const AdminChatsScreen()),
      const _AdminMenuTab(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;

        if (isWide) {
          // ── Tablet / iPad: side rail ─────────────────────────────────
          return Obx(() => Scaffold(
                backgroundColor: AppColors.background,
                body: Row(
                  children: [
                    _SideRail(selectedIndex: tab.value, onSelect: (i) => tab.value = i),
                    const VerticalDivider(
                      width: 1,
                      color: AppColors.border,
                    ),
                    Expanded(child: tabs[tab.value]),
                  ],
                ),
              ));
        }

        // ── Phone: bottom nav ─────────────────────────────────────────
        return Obx(() => Scaffold(
              backgroundColor: AppColors.background,
              body: tabs[tab.value],
              bottomNavigationBar: _BottomNav(
                selectedIndex: tab.value,
                onSelect: (i) => tab.value = i,
              ),
            ));
      },
    );
  }
}

// ── Side rail (tablet) ───────────────────────────────────────────────────────

class _SideRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _SideRail({required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      color: AppColors.surface,
      child: Column(
        children: [
          const SizedBox(height: 52),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt, color: AppColors.onPrimary, size: 22),
          ),
          const SizedBox(height: 24),
          ..._navItems.asMap().entries.map((e) {
            final selected = selectedIndex == e.key;
            return Tooltip(
              message: e.value.label,
              preferBelow: false,
              child: GestureDetector(
                onTap: () => onSelect(e.key),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        selected ? e.value.activeIcon : e.value.icon,
                        color: selected ? AppColors.primary : AppColors.textSecondary,
                        size: 22,
                      ),
                      if (e.value.badge != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Obx(() {
                            final count = e.value.badge!();
                            if (count == 0) return const SizedBox.shrink();
                            return Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.warning,
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Bottom nav (phone) ───────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _BottomNav({required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: _navItems.asMap().entries.map((e) {
              final selected = selectedIndex == e.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(e.key),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            selected ? e.value.activeIcon : e.value.icon,
                            color: selected ? AppColors.primary : AppColors.textSecondary,
                            size: 22,
                          ),
                          if (e.value.badge != null)
                            Positioned(
                              top: -3,
                              right: -5,
                              child: Obx(() {
                                final count = e.value.badge!();
                                if (count == 0) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    count > 9 ? '9+' : '$count',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                );
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.value.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
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

// ── Nav item model ────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int Function()? badge;
  const _NavItem(this.icon, this.activeIcon, this.label, [this.badge]);
}

List<_NavItem> get _navItems => [
      const _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
      const _NavItem(Icons.stadium_outlined, Icons.stadium, 'Arenas'),
      _NavItem(
        Icons.confirmation_number_outlined,
        Icons.confirmation_number,
        'Tickets',
        () => Get.isRegistered<TicketController>() ? TicketController.to.openCount : 0,
      ),
      const _NavItem(Icons.forum_outlined, Icons.forum, 'Chats'),
      const _NavItem(Icons.grid_view_outlined, Icons.grid_view, 'Menu'),
    ];

// ── Home tab ─────────────────────────────────────────────────────────────────

class _AdminHomeTab extends StatelessWidget {
  const _AdminHomeTab();

  @override
  Widget build(BuildContext context) {
    final admin = AdminController.to;
    final tournaments = TournamentController.to;
    final tickets = TicketController.to;
    final userName = AuthController.to.currentUser.value?.name;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userName?.split(' ').first ?? 'Admin',
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Obx(() {
                      final unread = admin.unreadNotifications;
                      return GestureDetector(
                        onTap: () => Get.toNamed(AppRoutes.adminNotifications),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.elevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.notifications_outlined,
                                  color: AppColors.textPrimary, size: 22),
                              if (unread > 0)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // ── Revenue hero card ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Obx(() {
                  if (!PermissionService.to.can(Permission.viewFinancials)) {
                    return const SizedBox.shrink();
                  }
                  return GestureDetector(
                      onTap: () => Get.toNamed(AppRoutes.adminRevenueAnalytics),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A2410), Color(0xFF0F1A0A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.payments_outlined,
                                      color: AppColors.primary, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Monthly Revenue',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.primary.withValues(alpha: 0.8),
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_forward_ios,
                                    color: AppColors.textSecondary, size: 14),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'PKR ${_formatRevenue(admin.monthlyRevenue)}',
                              style: AppTextStyles.scoreboardLarge.copyWith(
                                color: AppColors.primary,
                                fontSize: 36,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.trending_up,
                                          color: AppColors.success, size: 13),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Platform earnings',
                                        style: AppTextStyles.caption.copyWith(
                                            color: AppColors.success),
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
                }),
              ),
            ),

            // ── Attention needed ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Obx(() {
                final pendingArenas = admin.pendingArenas.length;
                final pendingBoosts = admin.pendingBoosts.length;
                final openTickets = tickets.openCount;
                final pendingTourneys = tournaments.pendingApproval.length;
                final total = pendingArenas + pendingBoosts + openTickets + pendingTourneys;
                if (total == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Needs attention',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (pendingArenas > 0)
                              _AttentionChip(
                                icon: Icons.stadium_outlined,
                                label: '$pendingArenas arena${pendingArenas > 1 ? 's' : ''} pending',
                                color: AppColors.warning,
                                onTap: () => Get.toNamed(AppRoutes.adminArenas),
                              ),
                            if (pendingBoosts > 0)
                              _AttentionChip(
                                icon: Icons.rocket_launch_outlined,
                                label: '$pendingBoosts boost${pendingBoosts > 1 ? 's' : ''}',
                                color: AppColors.accent,
                                onTap: () => Get.toNamed(AppRoutes.adminBoosts),
                              ),
                            if (openTickets > 0)
                              _AttentionChip(
                                icon: Icons.support_agent,
                                label: '$openTickets ticket${openTickets > 1 ? 's' : ''} open',
                                color: AppColors.error,
                                onTap: () => Get.toNamed(AppRoutes.adminTickets),
                              ),
                            if (pendingTourneys > 0)
                              _AttentionChip(
                                icon: Icons.emoji_events_outlined,
                                label: '$pendingTourneys tournament${pendingTourneys > 1 ? 's' : ''}',
                                color: AppColors.secondary,
                                onTap: () => Get.toNamed(AppRoutes.adminTournaments),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),

            // ── Stats grid ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  'Platform overview',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: Obx(() => SliverGrid(
                    delegate: SliverChildListDelegate([
                      _StatCard(
                        icon: Icons.group_outlined,
                        label: 'Total Users',
                        value: '${admin.totalUsers}',
                        color: AppColors.secondary,
                        onTap: () => Get.toNamed(AppRoutes.adminUsers),
                      ),
                      _StatCard(
                        icon: Icons.storefront_outlined,
                        label: 'Arena Owners',
                        value: '${admin.totalOwners}',
                        color: AppColors.primary,
                        onTap: () => Get.toNamed(AppRoutes.adminUsers),
                      ),
                      _StatCard(
                        icon: Icons.stadium_outlined,
                        label: 'Total Arenas',
                        value: '${admin.totalArenas}',
                        color: AppColors.accent,
                      ),
                      _StatCard(
                        icon: Icons.support_agent,
                        label: 'Staff',
                        value: '${admin.totalStaff}',
                        color: AppColors.secondary,
                        onTap: () => Get.toNamed(AppRoutes.adminStaffAnalytics),
                      ),
                      _StatCard(
                        icon: Icons.event_note_outlined,
                        label: 'Total Bookings',
                        value: '${admin.totalBookings}',
                        color: AppColors.primary,
                        onTap: () => Get.toNamed(AppRoutes.adminBookingAnalytics),
                      ),
                      _StatCard(
                        icon: Icons.calendar_today_outlined,
                        label: "Today's",
                        value: '${admin.todaysBookings}',
                        color: AppColors.success,
                        onTap: () => Get.toNamed(AppRoutes.adminBookingAnalytics),
                      ),
                    ]),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: _statCardMaxWidth(context),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.55,
                    ),
                  )),
            ),

            // ── Analytics quick actions (permission-gated) ───────────────
            SliverToBoxAdapter(
              child: Obx(() {
                final perm = PermissionService.to;
                final hasAnalytics = perm.can(Permission.viewAnalytics);
                final hasFinancials = perm.can(Permission.viewFinancials);
                if (!hasAnalytics && !hasFinancials) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Text(
                    'Analytics',
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary),
                  ),
                );
              }),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: Obx(() {
                final perm = PermissionService.to;
                final rows = <Widget>[];
                if (perm.can(Permission.viewAnalytics))
                  rows.addAll([
                    _MenuRow(
                      icon: Icons.query_stats,
                      title: 'Booking Analytics',
                      subtitle: 'Per-arena bookings, peak hours, trends',
                      color: AppColors.primary,
                      route: AppRoutes.adminBookingAnalytics,
                    ),
                    const SizedBox(height: 10),
                    _MenuRow(
                      icon: Icons.leaderboard_outlined,
                      title: 'Staff Analytics',
                      subtitle: 'Bookings handled, revenue, performance',
                      color: AppColors.secondary,
                      route: AppRoutes.adminStaffAnalytics,
                    ),
                  ]);
                if (perm.can(Permission.viewFinancials))
                  rows.addAll([
                    const SizedBox(height: 10),
                    _MenuRow(
                      icon: Icons.stacked_line_chart,
                      title: 'Revenue Analytics',
                      subtitle: 'Arena revenue, averages, line charts',
                      color: AppColors.success,
                      route: AppRoutes.adminRevenueAnalytics,
                    ),
                  ]);
                return SliverList(delegate: SliverChildListDelegate(rows));
              }),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  static double _statCardMaxWidth(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    if (w >= 1024) return 220;
    if (w >= 768) return 200;
    return 180;
  }

  static String _formatRevenue(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                if (onTap != null)
                  Icon(Icons.arrow_forward_ios,
                      size: 11, color: AppColors.textSecondary.withValues(alpha: 0.5)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.scoreboardMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
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

// ── Attention chip ────────────────────────────────────────────────────────────

class _AttentionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttentionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.label.copyWith(color: color, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Menu row ──────────────────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(route),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Menu tab ──────────────────────────────────────────────────────────────────

class _AdminMenuTab extends StatelessWidget {
  const _AdminMenuTab();

  @override
  Widget build(BuildContext context) {
    final admin = AdminController.to;
    final tournaments = TournamentController.to;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Row(
                  children: [
                    Text(
                      'Management',
                      style: AppTextStyles.headlineMedium.copyWith(
                          color: AppColors.textPrimary),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => AuthController.to.signOut(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.logout,
                                color: AppColors.error, size: 16),
                            const SizedBox(width: 6),
                            Text('Sign out',
                                style: AppTextStyles.label.copyWith(
                                    color: AppColors.error, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: Obx(() {
                    final perm = PermissionService.to;
                    return SliverList(
                      delegate: SliverChildListDelegate([
                        if (perm.can(Permission.viewBoosts))
                          AdminMenuTile(
                            icon: Icons.rocket_launch_outlined,
                            title: 'Boost Management',
                            subtitle: 'Requests, payments & history',
                            badge: admin.pendingBoosts.length,
                            route: AppRoutes.adminBoosts,
                            color: AppColors.accent,
                          ),
                        if (perm.can(Permission.viewUsers))
                          AdminMenuTile(
                            icon: Icons.group_outlined,
                            title: 'User Management',
                            subtitle: 'Ban/unban, roles, staff',
                            route: AppRoutes.adminUsers,
                            color: AppColors.secondary,
                          ),
                        if (perm.can(Permission.viewUsers))
                          AdminMenuTile(
                            icon: Icons.person_search_outlined,
                            title: 'Customer Management',
                            subtitle: 'Search, suspend, view history',
                            route: AppRoutes.adminCustomers,
                            color: AppColors.secondary,
                          ),
                        if (perm.can(Permission.viewAllBookings))
                          AdminMenuTile(
                            icon: Icons.calendar_month_outlined,
                            title: 'Booking Management',
                            subtitle: 'All bookings, approve, refund, cancel',
                            route: AppRoutes.adminBookings,
                            color: AppColors.accent,
                          ),
                        if (perm.can(Permission.viewFinancials))
                          AdminMenuTile(
                            icon: Icons.payments_outlined,
                            title: 'Finance & Payouts',
                            subtitle: 'Revenue, commissions, owner payouts',
                            route: AppRoutes.adminFinance,
                            color: AppColors.success,
                          ),
                        if (perm.can(Permission.manageTournaments))
                          AdminMenuTile(
                            icon: Icons.emoji_events_outlined,
                            title: 'Tournaments',
                            subtitle: 'Approvals & platform events',
                            badge: tournaments.pendingApproval.length,
                            route: AppRoutes.adminTournaments,
                            color: AppColors.primary,
                          ),
                        if (perm.can(Permission.viewAdminNotifications))
                          AdminMenuTile(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            subtitle: 'Bookings, tickets, boosts, payments',
                            badge: admin.unreadNotifications,
                            route: AppRoutes.adminNotifications,
                            color: AppColors.warning,
                          ),
                        if (perm.can(Permission.manageSettings))
                          AdminMenuTile(
                            icon: Icons.settings_outlined,
                            title: 'Platform Settings',
                            subtitle: 'Deposit %, cancellation, JazzCash',
                            route: AppRoutes.adminSettings,
                            color: AppColors.textSecondary,
                          ),
                        if (perm.can(Permission.viewAuditLogs))
                          AdminMenuTile(
                            icon: Icons.receipt_long_outlined,
                            title: 'Audit Logs',
                            subtitle: 'All admin & staff actions',
                            route: AppRoutes.adminAuditLogs,
                            color: AppColors.textSecondary,
                          ),
                        const SizedBox(height: 24),
                      ]),
                    );
                  }),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps a tab/screen in a reactive permission check.
/// Shows a "Permission Required" placeholder if the user lacks [permission].
/// Reacts immediately when Super Admin adds/removes a permission while logged in.
class _PermGate extends StatelessWidget {
  final Permission permission;
  final Widget child;
  const _PermGate(this.permission, this.child);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Reading currentUser.value makes this reactive to real-time profile updates.
      Get.find<AuthController>().currentUser.value;
      if (PermissionService.to.can(permission)) return child;
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: AppColors.textGrey),
                const SizedBox(height: 16),
                Text('Permission Required',
                    style: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  'You don\'t have access to this section.\nContact your Super Admin.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Shared menu tile — used by MenuTab and other admin screens.
class AdminMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final int badge;
  final Color color;

  const AdminMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.badge = 0,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => Get.toNamed(route),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (badge > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$badge',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(Icons.chevron_right,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
