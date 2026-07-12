import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/owner_booking_controller.dart';
import '../../controllers/owner_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile_tab.dart';
import 'dashboard_tab.dart';
import '../chat/my_chats_screen.dart';
import 'my_arenas_screen.dart';
import 'owner_bookings_screen.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lazy-register OwnerController here so it is available to all child tabs.
    if (!Get.isRegistered<OwnerController>()) {
      Get.put(OwnerController());
    }
    if (!Get.isRegistered<OwnerBookingController>()) {
      Get.put(OwnerBookingController(), permanent: true);
    }

    final RxInt tab = 0.obs;

    final tabs = const [
      DashboardTab(),
      OwnerBookingsScreen(),
      MyArenasScreen(),
      MyChatsScreen(),
      ProfileTab(),
    ];

    return Obx(
      () => Scaffold(
        body: tabs[tab.value],
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab.value,
          onDestinationSelected: (i) => tab.value = i,
          indicatorColor: AppColors.primary.withValues(alpha: 0.15),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon:
                  Icon(Icons.calendar_month, color: AppColors.primary),
              label: 'Bookings',
            ),
            NavigationDestination(
              icon: Icon(Icons.stadium_outlined),
              selectedIcon: Icon(Icons.stadium, color: AppColors.primary),
              label: 'My Arenas',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble, color: AppColors.primary),
              label: 'Chats',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
