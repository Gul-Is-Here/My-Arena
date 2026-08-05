import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/chat_controller.dart';
import '../../controllers/owner_booking_controller.dart';
import '../../controllers/owner_controller.dart';
import '../../controllers/staff_management_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass.dart';
import '../../widgets/profile_tab.dart';
import 'dashboard_tab.dart';
import '../chat/my_chats_screen.dart';
import 'my_arenas_screen.dart';
import 'my_team_screen.dart';
import 'owner_bookings_screen.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<OwnerController>()) {
      Get.put(OwnerController());
    }
    if (!Get.isRegistered<OwnerBookingController>()) {
      Get.put(OwnerBookingController(), permanent: true);
    }
    if (!Get.isRegistered<ChatController>()) {
      Get.put(ChatController(), permanent: true);
    }
    if (!Get.isRegistered<StaffManagementController>()) {
      Get.put(StaffManagementController(), permanent: true);
    }

    final owner = OwnerController.to;
    final chat = ChatController.to;

    final tabs = const [
      DashboardTab(),
      OwnerBookingsScreen(),
      MyArenasScreen(),
      MyTeamScreen(),
      MyChatsScreen(),
      ProfileTab(),
    ];

    return Obx(
      () {
        final unread = chat.totalUnread;
        return Scaffold(
          extendBody: true,
          body: tabs[owner.shellTab.value],
          bottomNavigationBar: GlassNavBar(
            selectedIndex: owner.shellTab.value,
            onDestinationSelected: (i) => owner.shellTab.value = i,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Dashboard',
              ),
              const NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Bookings',
              ),
              const NavigationDestination(
                icon: Icon(Icons.stadium_outlined),
                selectedIcon: Icon(Icons.stadium),
                label: 'My Arenas',
              ),
              const NavigationDestination(
                icon: Icon(Icons.group_outlined),
                selectedIcon: Icon(Icons.group),
                label: 'My Team',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread',
                      style: const TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: AppColors.error,
                  child: const Icon(Icons.chat_bubble_outline),
                ),
                selectedIcon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread',
                      style: const TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: AppColors.error,
                  child: const Icon(Icons.chat_bubble),
                ),
                label: 'Chats',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
