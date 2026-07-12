import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/booking_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/discovery_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile_tab.dart';
import '../booking/my_bookings_tab.dart';
import '../chat/my_chats_screen.dart';
import '../tournaments/tournaments_home_screen.dart';
import 'home_tab.dart';

class CustomerDashboardScreen extends StatelessWidget {
  const CustomerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<DiscoveryController>()) {
      Get.put(DiscoveryController());
    }
    if (!Get.isRegistered<BookingController>()) {
      Get.put(BookingController(), permanent: true);
    }
    if (!Get.isRegistered<ChatController>()) {
      Get.put(ChatController(), permanent: true);
    }

    // Optional int argument = initial tab (e.g. 1 → Bookings after checkout).
    final RxInt tab = (Get.arguments is int ? Get.arguments as int : 0).obs;

    final tabs = const [
      HomeTab(),
      MyBookingsTab(),
      TournamentsHomeScreen(),
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
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'Discover',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon:
                  Icon(Icons.calendar_today, color: AppColors.primary),
              label: 'Bookings',
            ),
            NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined),
              selectedIcon: Icon(Icons.emoji_events, color: AppColors.primary),
              label: 'Tournaments',
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
