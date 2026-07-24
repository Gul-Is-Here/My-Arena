import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/booking_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../data/models/notification_model.dart';
import '../../data/models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _bg = AppColors.background;
  static const _surface = AppColors.surface;
  static const _outline = AppColors.border;
  static const _blue = AppColors.secondary;
  static const _grey = AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    final c = NotificationController.to;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Obx(() => c.unreadCount > 0
              ? TextButton(
                  onPressed: c.markAllRead,
                  child: const Text('Mark all read',
                      style: TextStyle(color: AppColors.primary, fontSize: 13)),
                )
              : const SizedBox.shrink()),
        ],
      ),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (c.notifications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off_outlined, size: 56, color: _grey),
                SizedBox(height: 12),
                Text('No notifications yet',
                    style: TextStyle(color: _grey, fontSize: 15)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: c.notifications.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _NotificationTile(n: c.notifications[i]),
        );
      }),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel n;
  const _NotificationTile({required this.n});

  void _navigate() {
    if (n.relatedId == null || n.relatedId!.isEmpty) return;

    switch (n.type) {
      case 'booking':
        final role = AuthController.to.currentUser.value?.role;
        if (role == UserRole.owner || role == UserRole.staff) {
          Get.toNamed(AppRoutes.bookingDetailOwner, arguments: n.relatedId);
        } else {
          // Customer — look up the already-loaded BookingModel by id.
          final bc = Get.find<BookingController>();
          final booking = bc.bookings.firstWhereOrNull(
            (b) => b.id == n.relatedId,
          );
          if (booking != null) {
            Get.toNamed(AppRoutes.bookingDetail, arguments: booking);
          }
        }
        break;
      case 'tournament':
        Get.toNamed(AppRoutes.tournamentDetail, arguments: n.relatedId);
        break;
      default:
        break;
    }
  }

  IconData get _icon {
    switch (n.type) {
      case 'booking':
        return Icons.event_available;
      case 'review':
        return Icons.star_outline;
      case 'boost':
        return Icons.rocket_launch_outlined;
      case 'waitlist':
        return Icons.hourglass_top;
      case 'tournament':
        return Icons.emoji_events_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String get _timeAgo {
    final diff = DateTime.now().difference(n.createdAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${n.createdAt.day}/${n.createdAt.month}/${n.createdAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!n.read) NotificationController.to.markRead(n.id);
        _navigate();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.read
              ? NotificationsScreen._surface
              : NotificationsScreen._blue.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: n.read
                ? NotificationsScreen._outline
                : NotificationsScreen._blue.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: NotificationsScreen._blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: NotificationsScreen._blue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight:
                                n.read ? FontWeight.w600 : FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(_timeAgo,
                          style: const TextStyle(
                              color: NotificationsScreen._grey, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.body,
                    style: const TextStyle(
                        color: NotificationsScreen._grey,
                        fontSize: 13,
                        height: 1.35),
                  ),
                ],
              ),
            ),
            if (!n.read)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
