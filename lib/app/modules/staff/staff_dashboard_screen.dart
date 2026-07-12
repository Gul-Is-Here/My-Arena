import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/owner_booking_controller.dart';
import '../../controllers/ticket_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';

/// Staff panel — limited admin access: approvals + support chat.
/// Reuses the admin management screens and the owner bookings screen.
class StaffDashboardScreen extends StatelessWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AdminController>()) {
      Get.put(AdminController(), permanent: true);
    }
    if (!Get.isRegistered<OwnerBookingController>()) {
      Get.put(OwnerBookingController(), permanent: true);
    }
    if (!Get.isRegistered<TicketController>()) {
      Get.put(TicketController(), permanent: true);
    }
    final admin = AdminController.to;
    final bookings = OwnerBookingController.to;
    final tickets = TicketController.to;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Panel'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthController.to.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Approvals & Support', style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Handle approvals and help users — limited admin access.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textGrey),
          ),
          const SizedBox(height: 16),
          Obx(
            () => Column(
              children: [
                _tile(
                  icon: Icons.stadium_outlined,
                  title: 'Arena Approvals',
                  subtitle: 'Review submitted arenas',
                  badge: admin.pendingArenas.length,
                  route: AppRoutes.adminArenas,
                ),
                _tile(
                  icon: Icons.calendar_month_outlined,
                  title: 'Booking Approvals',
                  subtitle: 'Verify deposits, approve bookings',
                  badge: bookings.pendingApproval.length,
                  route: AppRoutes.ownerBookings,
                ),
                _tile(
                  icon: Icons.rocket_launch_outlined,
                  title: 'Boost Approvals',
                  subtitle: 'Review boost payment requests',
                  badge: admin.pendingBoosts.length,
                  route: AppRoutes.adminBoosts,
                ),
                _tile(
                  icon: Icons.confirmation_number_outlined,
                  title: 'Support Tickets',
                  subtitle: 'Reply, assign, resolve tickets',
                  badge: tickets.openCount,
                  route: AppRoutes.adminTickets,
                ),
                _tile(
                  icon: Icons.support_agent,
                  title: 'Support Chats',
                  subtitle: 'Reply to customer & owner chats',
                  route: AppRoutes.myChats,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    int badge = 0,
  }) {
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
