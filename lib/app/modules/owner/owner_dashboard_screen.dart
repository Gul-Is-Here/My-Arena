import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/chat_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../controllers/owner_booking_controller.dart';
import '../../controllers/owner_controller.dart';
import '../../controllers/staff_management_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../chat/my_chats_screen.dart';
import 'dashboard_tab.dart';
import 'my_arenas_screen.dart';
import 'my_team_screen.dart';
import 'owner_bookings_screen.dart';
import '../../widgets/profile_tab.dart';

const _kTablet = 720.0;
const _kDesktop = 1100.0;

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<OwnerController>()) Get.put(OwnerController(), permanent: true);
    if (!Get.isRegistered<OwnerBookingController>()) {
      Get.put(OwnerBookingController(), permanent: true);
    }
    if (!Get.isRegistered<ChatController>()) {
      Get.put(ChatController(), permanent: true);
    }
    if (!Get.isRegistered<StaffManagementController>()) {
      Get.put(StaffManagementController(), permanent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return constraints.maxWidth >= _kTablet
          ? const _WideShell()
          : const _NarrowShell();
    });
  }
}

// ── Destination model ──────────────────────────────────────────────────────

class _Dest {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _Dest(this.icon, this.activeIcon, this.label);
}

const _destinations = [
  _Dest(Icons.home_outlined, Icons.home_rounded, 'Dashboard'),
  _Dest(Icons.calendar_month_outlined, Icons.calendar_month, 'Bookings'),
  _Dest(Icons.stadium_outlined, Icons.stadium, 'My Arenas'),
  _Dest(Icons.group_outlined, Icons.group, 'My Team'),
  _Dest(Icons.chat_bubble_outline, Icons.chat_bubble, 'Chats'),
  _Dest(Icons.person_outline, Icons.person, 'Profile'),
];

const _tabs = [
  DashboardTab(),
  OwnerBookingsScreen(),
  MyArenasScreen(),
  MyTeamScreen(),
  MyChatsScreen(),
  ProfileTab(),
];

// ── MOBILE SHELL ──────────────────────────────────────────────────────────────

class _NarrowShell extends StatelessWidget {
  const _NarrowShell();

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<OwnerController>() ||
        !Get.isRegistered<ChatController>()) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final owner = OwnerController.to;
    final chat = ChatController.to;

    return Obx(() {
      final tab = owner.shellTab.value;
      final unread = chat.totalUnread;

      return Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true,
        body: IndexedStack(index: tab, children: _tabs),
        bottomNavigationBar: _MobileBottomNav(
          selectedIndex: tab,
          unread: unread,
          onTap: (i) => owner.shellTab.value = i,
        ),
      );
    });
  }
}

class _MobileBottomNav extends StatelessWidget {
  final int selectedIndex;
  final int unread;
  final ValueChanged<int> onTap;
  const _MobileBottomNav({
    required this.selectedIndex,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labels = ['Home', 'Bookings', 'Arenas', 'Team', 'Chats', 'Profile'];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.97),
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_destinations.length, (i) {
              final active = selectedIndex == i;
              final dest = _destinations[i];
              final hasChat = i == 4 && unread > 0;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: active ? 44 : 36,
                            height: active ? 28 : 26,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primary.withValues(alpha: 0.14)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              active ? dest.activeIcon : dest.icon,
                              color: active
                                  ? AppColors.primary
                                  : AppColors.textDisabled,
                              size: 20,
                            ),
                          ),
                          if (hasChat)
                            Positioned(
                              top: -3,
                              right: -3,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unread > 9 ? '9+' : '$unread',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: AppTextStyles.caption.copyWith(
                          color: active
                              ? AppColors.primary
                              : AppColors.textDisabled,
                          fontSize: 9,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                        child: Text(labels[i]),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── WIDE SHELL (custom sidebar) ───────────────────────────────────────────────

class _WideShell extends StatelessWidget {
  const _WideShell();

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<OwnerController>() ||
        !Get.isRegistered<ChatController>()) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final owner = OwnerController.to;
    final chat = ChatController.to;
    final screenW = MediaQuery.sizeOf(context).width;
    final extended = screenW >= _kDesktop;

    return Obx(() {
      final tab = owner.shellTab.value;
      final unread = chat.totalUnread;
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(children: [
          _Sidebar(
            tab: tab,
            extended: extended,
            unread: unread,
            onSelect: (i) => owner.shellTab.value = i,
          ),
          Expanded(child: IndexedStack(index: tab, children: _tabs)),
        ]),
      );
    });
  }
}

// ── Custom Sidebar ────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final int tab;
  final bool extended;
  final int unread;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.tab,
    required this.extended,
    required this.unread,
    required this.onSelect,
  });

  static const _navItems = [
    _SidebarItem(Icons.home_rounded, 'Dashboard', null),
    _SidebarItem(Icons.calendar_month_rounded, 'Bookings', null),
    _SidebarItem(Icons.stadium_rounded, 'My Arenas', null),
    _SidebarItem(Icons.group_rounded, 'My Team', null),
    _SidebarItem(Icons.chat_bubble_rounded, 'Chats', null),
    _SidebarItem(Icons.person_rounded, 'Profile', null),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: extended ? 220 : 68,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Column(children: [
          // Logo
          _logo(extended),
          // Nav groups
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(children: [
                if (extended) _groupLabel('Main'),
                ...[0, 1, 2].map((i) => _navTile(i, _navItems[i], 0)),
                if (extended) _groupLabel('Management'),
                ...[3, 4, 5].map((i) => _navTile(i, _navItems[i], i == 4 ? unread : 0)),
                // POS quick-launch
                const SizedBox(height: 8),
                if (extended) _groupLabel('Tools'),
                _posLaunch(extended),
              ]),
            ),
          ),
          // Pending indicator
          Obx(() {
            final pending = OwnerBookingController.to.pendingApproval.length;
            if (pending == 0) return const SizedBox.shrink();
            return _pendingBar(pending, extended);
          }),
          const Divider(color: AppColors.border, height: 1),
          // Notification row
          _bottomRow(extended),
        ]),
      ),
    );
  }

  Widget _logo(bool ext) {
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: ext ? 16 : 0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: ext ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2ae500), Color(0xFF00dbe9)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text('A',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    height: 1,
                  )),
            ),
          ),
          if (ext) ...[
            const SizedBox(width: 10),
            const Text('ArenaPro',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                )),
          ],
        ],
      ),
    );
  }

  Widget _groupLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              )),
        ),
      );

  Widget _navTile(int i, _SidebarItem item, int badge) {
    final active = tab == i;
    return GestureDetector(
      onTap: () => onSelect(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        padding: EdgeInsets.symmetric(
            horizontal: extended ? (active ? 8 : 10) : 0, vertical: 9),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.13),
                    AppColors.primary.withValues(alpha: 0.04),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(10),
          border: active
              ? const Border(
                  left: BorderSide(color: AppColors.primary, width: 2),
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment:
              extended ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(item.icon,
                color: active ? AppColors.primary : AppColors.textSecondary,
                size: 19),
            if (extended) ...[
              const SizedBox(width: 9),
              Expanded(
                child: Text(item.label,
                    style: TextStyle(
                      color: active
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                    )),
              ),
              if (badge > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('$badge',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      )),
                ),
            ] else if (badge > 0)
              Positioned(
                top: 0, right: 0,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error, shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _posLaunch(bool ext) {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.posDashboard),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: EdgeInsets.symmetric(
            horizontal: ext ? 10 : 0, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment:
              ext ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            const Icon(Icons.point_of_sale_rounded,
                color: AppColors.success, size: 19),
            if (ext) ...[
              const SizedBox(width: 9),
              const Text('POS',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pendingBar(int count, bool ext) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment:
            ext ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_top_rounded,
              color: AppColors.error, size: 15),
          if (ext) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text('$count pending approval',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomRow(bool ext) {
    return Obx(() {
      final notifCount =
          NotificationController.to.unreadCount;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment:
              ext ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => Get.toNamed(AppRoutes.notifications),
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.notifications_outlined,
                      color: AppColors.textSecondary, size: 18),
                ),
                if (notifCount > 0)
                  Positioned(
                    top: -3, right: -3,
                    child: Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.warning, shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ]),
            ),
          ],
        ),
      );
    });
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  final String? route;
  const _SidebarItem(this.icon, this.label, this.route);
}
