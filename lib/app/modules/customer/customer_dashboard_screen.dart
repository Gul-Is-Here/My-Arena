import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/booking_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/discovery_controller.dart';
import '../../controllers/favorites_controller.dart';
import '../../widgets/profile_tab.dart';
import '../booking/my_bookings_tab.dart';
import '../chat/my_chats_screen.dart';
import '../tournaments/tournaments_home_screen.dart';
import 'home_tab.dart';

class CustomerDashboardScreen extends StatelessWidget {
  const CustomerDashboardScreen({super.key});

  static const _surfaceLow = Color(0xFF191C22);
  static const _cyan = Color(0xFF00DBE9);
  static const _onSurfaceVar = Color(0xFFB9CACB);
  static const _outlineVar = Color(0xFF3B494B);

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<DiscoveryController>()) {
      Get.put(DiscoveryController(), permanent: true);
    }
    if (!Get.isRegistered<BookingController>()) {
      Get.put(BookingController(), permanent: true);
    }
    if (!Get.isRegistered<ChatController>()) {
      Get.put(ChatController(), permanent: true);
    }
    if (!Get.isRegistered<FavoritesController>()) {
      Get.put(FavoritesController(), permanent: true);
    }

    final RxInt tab =
        (Get.arguments is int ? Get.arguments as int : 0).obs;

    const tabs = [
      HomeTab(),
      MyBookingsTab(),
      TournamentsHomeScreen(),
      MyChatsScreen(),
      ProfileTab(),
    ];

    const navItems = [
      _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
      _NavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Bookings'),
      _NavItem(icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events, label: 'Events'),
      _NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Chats'),
      _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
    ];

    return Obx(
      () => Scaffold(
        backgroundColor: const Color(0xFF10131A),
        extendBody: true,
        body: tabs[tab.value],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: _surfaceLow,
            border: Border(
              top: BorderSide(color: _outlineVar.withValues(alpha: 0.4)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(navItems.length, (i) {
                  final item = navItems[i];
                  final active = tab.value == i;
                  return GestureDetector(
                    onTap: () => tab.value = i,
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.symmetric(
                        horizontal: active ? 16 : 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? _cyan.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            active ? item.activeIcon : item.icon,
                            color: active ? _cyan : _onSurfaceVar,
                            size: 22,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              letterSpacing: 0.4,
                              color: active ? _cyan : _onSurfaceVar,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(
      {required this.icon, required this.activeIcon, required this.label});
}
