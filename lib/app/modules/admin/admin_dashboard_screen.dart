import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../controllers/analytics_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/ticket_controller.dart';
import '../../controllers/tournament_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import 'admin_arenas_screen.dart';
import 'admin_chats_screen.dart';
import 'admin_tickets_screen.dart';

/// Admin shell — bottom nav: Dashboard | Arenas | Tickets | Chats | Menu.
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

    final tabs = const [
      _AdminHomeTab(),
      AdminArenasScreen(),
      AdminTicketsScreen(),
      AdminChatsScreen(),
      _AdminMenuTab(),
    ];

    return Obx(
      () => Scaffold(
        body: tabs[tab.value],
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab.value,
          onDestinationSelected: (i) => tab.value = i,
          indicatorColor: AppColors.primary.withValues(alpha: 0.15),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
              label: 'Dashboard',
            ),
            const NavigationDestination(
              icon: Icon(Icons.stadium_outlined),
              selectedIcon: Icon(Icons.stadium, color: AppColors.primary),
              label: 'Arenas',
            ),
            NavigationDestination(
              icon: Obx(() {
                final open = TicketController.to.openCount;
                return Badge(
                  isLabelVisible: open > 0,
                  label: Text('$open'),
                  child: const Icon(Icons.confirmation_number_outlined),
                );
              }),
              selectedIcon: const Icon(Icons.confirmation_number,
                  color: AppColors.primary),
              label: 'Tickets',
            ),
            const NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum, color: AppColors.primary),
              label: 'Chats',
            ),
            const NavigationDestination(
              icon: Icon(Icons.menu),
              selectedIcon: Icon(Icons.menu_open, color: AppColors.primary),
              label: 'Menu',
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashboard tab — stat cards + analytics shortcuts.
class _AdminHomeTab extends StatelessWidget {
  const _AdminHomeTab();

  @override
  Widget build(BuildContext context) {
    final admin = AdminController.to;
    final tournaments = TournamentController.to;
    final tickets = TicketController.to;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        automaticallyImplyLeading: false,
        actions: [
          Obx(() {
            final unread = admin.unreadNotifications;
            return IconButton(
              onPressed: () => Get.toNamed(AppRoutes.adminNotifications),
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications_outlined),
              ),
            );
          }),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Stats ───────────────────────────────────────────────────
          Obx(
            () => GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.7,
              children: [
                _stat(Icons.group_outlined, 'Total Users',
                    '${admin.totalUsers}', AppColors.primary,
                    onTap: () => Get.toNamed(AppRoutes.adminUsers)),
                _stat(Icons.storefront_outlined, 'Arena Owners',
                    '${admin.totalOwners}', AppColors.accent,
                    onTap: () => Get.toNamed(AppRoutes.adminUsers)),
                _stat(Icons.support_agent, 'Total Staff',
                    '${admin.totalStaff}', AppColors.primary,
                    onTap: () => Get.toNamed(AppRoutes.adminStaffAnalytics)),
                _stat(Icons.stadium_outlined, 'Total Arenas',
                    '${admin.totalArenas}', AppColors.accent),
                _stat(Icons.event_note_outlined, 'Total Bookings',
                    '${admin.totalBookings.value}', AppColors.primary,
                    onTap: () =>
                        Get.toNamed(AppRoutes.adminBookingAnalytics)),
                _stat(Icons.calendar_today_outlined, "Today's Bookings",
                    '${admin.todaysBookings.value}', AppColors.accent,
                    onTap: () =>
                        Get.toNamed(AppRoutes.adminBookingAnalytics)),
                _stat(
                    Icons.payments_outlined,
                    'Monthly Revenue',
                    'PKR ${(admin.monthlyRevenue.value / 1000).toStringAsFixed(0)}k',
                    AppColors.success,
                    onTap: () =>
                        Get.toNamed(AppRoutes.adminRevenueAnalytics)),
                _stat(Icons.rocket_launch_outlined, 'Active Boosts',
                    '${admin.activeBoosts.length}', AppColors.success,
                    onTap: () => Get.toNamed(AppRoutes.adminBoosts)),
                _stat(Icons.pending_actions, 'Pending Boosts',
                    '${admin.pendingBoosts.length}', AppColors.warning,
                    onTap: () => Get.toNamed(AppRoutes.adminBoosts)),
                _stat(Icons.emoji_events_outlined, 'Pending Tournaments',
                    '${tournaments.pendingApproval.length}',
                    AppColors.warning,
                    onTap: () => Get.toNamed(AppRoutes.adminTournaments)),
                _stat(Icons.confirmation_number_outlined, 'Open Tickets',
                    '${tickets.openCount}', AppColors.warning,
                    onTap: () => Get.toNamed(AppRoutes.adminTickets)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text('Analytics & Reports', style: AppTextStyles.titleLarge),
          const SizedBox(height: 12),
          AdminMenuTile(
            icon: Icons.query_stats,
            title: 'Booking Analytics',
            subtitle: 'Per-arena bookings, peak hours, trends',
            route: AppRoutes.adminBookingAnalytics,
          ),
          AdminMenuTile(
            icon: Icons.stacked_line_chart,
            title: 'Revenue Analytics',
            subtitle: 'Arena revenue, averages, charts',
            route: AppRoutes.adminRevenueAnalytics,
          ),
          AdminMenuTile(
            icon: Icons.leaderboard_outlined,
            title: 'Staff Analytics',
            subtitle: 'Bookings handled, revenue, performance',
            route: AppRoutes.adminStaffAnalytics,
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value, Color color,
      {VoidCallback? onTap}) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTextStyles.headlineMedium),
              Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textGrey)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Menu tab — remaining management modules + logout.
class _AdminMenuTab extends StatelessWidget {
  const _AdminMenuTab();

  @override
  Widget build(BuildContext context) {
    final admin = AdminController.to;
    final tournaments = TournamentController.to;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Management'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthController.to.signOut(),
          ),
        ],
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminMenuTile(
              icon: Icons.rocket_launch_outlined,
              title: 'Boost Management',
              subtitle: 'Requests, payments & history',
              badge: admin.pendingBoosts.length,
              route: AppRoutes.adminBoosts,
            ),
            AdminMenuTile(
              icon: Icons.group_outlined,
              title: 'User Management',
              subtitle: 'Ban/unban, roles, staff',
              route: AppRoutes.adminUsers,
            ),
            AdminMenuTile(
              icon: Icons.emoji_events_outlined,
              title: 'Tournaments',
              subtitle: 'Approvals & platform events',
              badge: tournaments.pendingApproval.length,
              route: AppRoutes.adminTournaments,
            ),
            AdminMenuTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Bookings, tickets, boosts, payments',
              badge: admin.unreadNotifications,
              route: AppRoutes.adminNotifications,
            ),
            AdminMenuTile(
              icon: Icons.settings_outlined,
              title: 'Platform Settings',
              subtitle: 'Deposit %, cancellation, JazzCash',
              route: AppRoutes.adminSettings,
            ),
            AdminMenuTile(
              icon: Icons.receipt_long_outlined,
              title: 'Audit Logs',
              subtitle: 'All admin & staff actions',
              route: AppRoutes.adminAuditLogs,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared menu tile used by the Dashboard and Menu tabs.
class AdminMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final int badge;

  const AdminMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => Get.toNamed(route),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
                  Text(subtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textGrey)),
                ],
              ),
            ),
            if (badge > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$badge',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.black, fontWeight: FontWeight.w700)),
              ),
            const Icon(Icons.chevron_right, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}
