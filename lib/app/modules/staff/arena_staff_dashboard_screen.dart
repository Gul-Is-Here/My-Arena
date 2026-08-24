import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../controllers/owner_booking_controller.dart';
import '../../controllers/owner_schedule_controller.dart';
import '../../controllers/staff_management_controller.dart';
import '../../data/models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/glass.dart';
import '../../widgets/profile_tab.dart';
import '../chat/my_chats_screen.dart';
import '../owner/owner_bookings_screen.dart';

/// Full-featured dashboard for arena-assigned staff.
class ArenaStaffDashboardScreen extends StatefulWidget {
  const ArenaStaffDashboardScreen({super.key});

  @override
  State<ArenaStaffDashboardScreen> createState() =>
      _ArenaStaffDashboardScreenState();
}

class _ArenaStaffDashboardScreenState
    extends State<ArenaStaffDashboardScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Register controllers once at mount time, not on every build().
    if (!Get.isRegistered<StaffManagementController>()) {
      Get.put(StaffManagementController(), permanent: true);
    }
    if (!Get.isRegistered<OwnerBookingController>()) {
      Get.put(OwnerBookingController(), permanent: true);
    }
    if (!Get.isRegistered<ChatController>()) {
      Get.put(ChatController(), permanent: true);
    }
    if (!Get.isRegistered<OwnerScheduleController>()) {
      Get.put(OwnerScheduleController(), permanent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final unread = ChatController.to.totalUnread;
      return Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _tab,
          children: const [
            _ArenasTab(),
            OwnerBookingsScreen(),
            MyChatsScreen(),
            ProfileTab(),
          ],
        ),
        bottomNavigationBar: GlassNavBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.stadium_outlined),
              selectedIcon: Icon(Icons.stadium),
              label: 'My Arenas',
            ),
            const NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Bookings',
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
    });
  }
}

// ── Arenas tab ────────────────────────────────────────────────────────────────

class _ArenasTab extends StatelessWidget {
  const _ArenasTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Arenas'),
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          Obx(() {
            final unread = NotificationController.to.unreadCount;
            return IconButton(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                backgroundColor: AppColors.error,
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () => Get.toNamed(AppRoutes.notifications),
              tooltip: 'Notifications',
            );
          }),
        ],
      ),
      // Observe only the reactive field we care about — assignedArenas.
      // AuthController.to.currentUser is already an Rx value; Obx here
      // rebuilds only when the user object itself changes (login/logout/update).
      body: Obx(() {
        final user = AuthController.to.currentUser.value;
        if (user == null) return const SizedBox.shrink();
        if (user.assignedArenas.isEmpty) return const _EmptyState();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: user.assignedArenas.length,
          itemBuilder: (_, i) =>
              _ArenaCard(arenaId: user.assignedArenas[i], user: user),
        );
      }),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.stadium_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text('No arenas assigned', style: AppTextStyles.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Contact your owner to get access.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Arena Card ────────────────────────────────────────────────────────────────

// Session-level cache: avoids re-fetching the same arena doc every time the
// list rebuilds (e.g. after a notification arrives and currentUser emits).
final Map<String, ({String name, String location})> _arenaCache = {};

class _ArenaCard extends StatefulWidget {
  final String arenaId;
  final UserModel user;

  const _ArenaCard({required this.arenaId, required this.user});

  @override
  State<_ArenaCard> createState() => _ArenaCardState();
}

class _ArenaCardState extends State<_ArenaCard> {
  String _name = '';
  String _location = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final cached = _arenaCache[widget.arenaId];
    if (cached != null) {
      _name = cached.name;
      _location = cached.location;
      _loading = false;
    } else {
      _fetchArena();
    }
  }

  Future<void> _fetchArena() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('arenas')
          .doc(widget.arenaId)
          .get();
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data()!;
        final name = (data['name'] as String?) ?? widget.arenaId;
        final loc = data['location'];
        final location = (loc is Map) ? ((loc['address'] as String?) ?? '') : '';
        _arenaCache[widget.arenaId] = (name: name, location: location);
        setState(() {
          _name = name;
          _location = location;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _CardSkeleton();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            _CardHeader(
              arenaId: widget.arenaId,
              name: _name,
              location: _location,
            ),
            // ── Divider ─────────────────────────────────────────────────
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border,
            ),
            // ── Action grid ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: _ActionGrid(arenaId: widget.arenaId),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card Header ───────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final String arenaId;
  final String name;
  final String location;

  const _CardHeader({
    required this.arenaId,
    required this.name,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        children: [
          // Arena icon badge
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.secondary.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Icon(Icons.stadium_rounded,
                color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : arenaId,
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          location,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Grid ───────────────────────────────────────────────────────────────

class _ActionGrid extends StatelessWidget {
  final String arenaId;

  const _ActionGrid({required this.arenaId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Primary row — core daily actions
        Row(
          children: [
            _ActionTile(
              icon: Icons.calendar_month_outlined,
              label: 'Bookings',
              onTap: () => Get.toNamed(AppRoutes.ownerBookings),
              isPrimary: true,
            ),
            const SizedBox(width: 8),
            _ActionTile(
              icon: Icons.calendar_view_week_outlined,
              label: 'Schedule',
              onTap: () => Get.toNamed(AppRoutes.ownerSchedule),
              isPrimary: true,
            ),
            const SizedBox(width: 8),
            _ActionTile(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan QR',
              onTap: () => Get.toNamed(AppRoutes.ownerQrScanner),
              isPrimary: true,
              highlight: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Secondary row — management actions
        Row(
          children: [
            _ActionTile(
              icon: Icons.book_online_outlined,
              label: 'Manual Book',
              onTap: () => Get.toNamed(AppRoutes.manualBooking),
              isPrimary: false,
            ),
            const SizedBox(width: 8),
            _ActionTile(
              icon: Icons.edit_outlined,
              label: 'Edit Arena',
              onTap: () =>
                  Get.toNamed(AppRoutes.editArena, arguments: arenaId),
              isPrimary: false,
            ),
            const SizedBox(width: 8),
            _ActionTile(
              icon: Icons.sports_tennis_outlined,
              label: 'Courts',
              onTap: () => Get.toNamed(AppRoutes.arenaDetailOwner,
                  arguments: arenaId),
              isPrimary: false,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Action Tile ───────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool highlight;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPrimary,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = highlight
        ? AppColors.primary
        : isPrimary
            ? AppColors.textPrimary
            : AppColors.textSecondary;
    final bgColor = highlight
        ? AppColors.primary.withValues(alpha: 0.12)
        : AppColors.elevated;
    final borderColor = highlight
        ? AppColors.primary.withValues(alpha: 0.35)
        : AppColors.border;

    return Expanded(
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1),
            ),
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: isPrimary ? 20 : 18, color: iconColor),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: isPrimary
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _CardSkeleton extends StatefulWidget {
  const _CardSkeleton();

  @override
  State<_CardSkeleton> createState() => _CardSkeletonState();
}

class _CardSkeletonState extends State<_CardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final shimmer =
              AppColors.elevated.withValues(alpha: _anim.value + 0.3);
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: shimmer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 14,
                          decoration: BoxDecoration(
                            color: shimmer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 90,
                          height: 10,
                          decoration: BoxDecoration(
                            color: shimmer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: List.generate(
                    3,
                    (i) => Expanded(
                      child: Container(
                        height: 56,
                        margin: EdgeInsets.only(left: i == 0 ? 0 : 8),
                        decoration: BoxDecoration(
                          color: shimmer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(
                    3,
                    (i) => Expanded(
                      child: Container(
                        height: 56,
                        margin: EdgeInsets.only(left: i == 0 ? 0 : 8),
                        decoration: BoxDecoration(
                          color: shimmer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
