import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/booking_controller.dart';
import '../../controllers/discovery_controller.dart';
import '../../controllers/favorites_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../data/models/arena_model.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/court_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/arena_image.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final discovery = DiscoveryController.to;

    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Sticky header ────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _TopBarDelegate(discovery: discovery),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search bar + quick filters
                    _SearchBar(),
                    const SizedBox(height: 10),
                    _QuickFilterRow(discovery: discovery),
                    const SizedBox(height: 14),

                    // Promo hero banner carousel
                    Obx(() {
                      if (discovery.featured.isEmpty) return const SizedBox.shrink();
                      return Column(
                        children: [
                          _PromoBannerCarousel(arenas: discovery.featured),
                          const SizedBox(height: 28),
                        ],
                      );
                    }),

                    // Upcoming booking
                    Obx(() {
                      if (!Get.isRegistered<BookingController>()) return const SizedBox.shrink();
                      final bc = Get.find<BookingController>();
                      if (bc.upcoming.isEmpty) return const SizedBox.shrink();
                      return Column(
                        children: [
                          _UpcomingCard(booking: bc.upcoming.first),
                          const SizedBox(height: 28),
                        ],
                      );
                    }),

                    // Saved arenas
                    Obx(() {
                      if (!Get.isRegistered<FavoritesController>()) {
                        return const SizedBox.shrink();
                      }
                      final fc = FavoritesController.to;
                      if (fc.ids.isEmpty) return const SizedBox.shrink();
                      final saved = discovery.savedArenas(fc.ids);
                      if (saved.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            title: 'Saved Arenas',
                            onViewAll: () => Get.toNamed(AppRoutes.arenaList),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 232,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: saved.length,
                              separatorBuilder: (context, i) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (_, i) =>
                                  _FeaturedCard(arena: saved[i]),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      );
                    }),

                    // Featured arenas
                    _SectionHeader(
                      title: 'Featured Arenas',
                      onViewAll: () => Get.toNamed(AppRoutes.arenaList),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 232,
                      child: Obx(() => ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: discovery.featured.length,
                        separatorBuilder: (c, i) => const SizedBox(width: 12),
                        itemBuilder: (_, i) =>
                            _FeaturedCard(arena: discovery.featured[i]),
                      )),
                    ),
                    const SizedBox(height: 28),

                    // Nearby arenas
                    _SectionHeader(
                      title: 'Nearby Arenas',
                      onViewAll: () => Get.toNamed(AppRoutes.arenaList),
                    ),
                    const SizedBox(height: 12),
                    Obx(() => Column(
                      children: discovery.nearby
                          .map((a) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _NearbyCard(arena: a),
                              ))
                          .toList(),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top Bar ────────────────────────────────────────────────────────────────────

class _TopBarDelegate extends SliverPersistentHeaderDelegate {
  final DiscoveryController discovery;
  const _TopBarDelegate({required this.discovery});

  @override
  double get minExtent => 64;
  @override
  double get maxExtent => 64;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Location
          const Icon(Icons.location_on, color: AppColors.secondary, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT HUB',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                Obx(() => Text(
                      discovery.cityName.value,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )),
              ],
            ),
          ),
          // Brand
          Text(
            'ArenaPro',
            style: AppTextStyles.titleLarge.copyWith(
              fontSize: 17,
              color: AppColors.secondary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 12),
          // Notifications bell
          GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.notifications),
            child: Obx(() {
              final unread = NotificationController.to.unreadCount;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.elevated,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_outlined,
                        color: AppColors.secondary, size: 20),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
          const SizedBox(width: 10),
          // Search icon
          GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.arenaList),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.elevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search, color: AppColors.secondary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TopBarDelegate old) => false;
}

// ── Search Bar ─────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.arenaList),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.elevated,
          border: const Border(
            bottom: BorderSide(color: AppColors.border, width: 2),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search sports, arenas, or events…',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Promo Banner Carousel ──────────────────────────────────────────────────────

class _PromoBannerCarousel extends StatefulWidget {
  final List<ArenaModel> arenas;
  const _PromoBannerCarousel({required this.arenas});

  @override
  State<_PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<_PromoBannerCarousel> {
  final PageController _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: widget.arenas.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _PromoBanner(arena: widget.arenas[i]),
          ),
        ),
        if (widget.arenas.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.arenas.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.textSecondary,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _PromoBanner extends StatelessWidget {
  final ArenaModel arena;
  const _PromoBanner({required this.arena});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.arenaDetailCustomer, arguments: arena.id),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              ArenaImage(
                path: arena.images.isNotEmpty ? arena.images.first : null,
                height: 220,
                width: double.infinity,
              ),
              // Gradient overlay
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.background.withValues(alpha: 0.5),
                      AppColors.background.withValues(alpha: 0.92),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              // Content
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      color: AppColors.secondary,
                      child: Text(
                        'SEASON PASS',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      arena.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineMedium.copyWith(
                        fontSize: 22,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      arena.location.displayAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _SecondaryButton(
                          label: 'BOOK NOW',
                          icon: Icons.arrow_forward,
                          onTap: () => Get.toNamed(
                              AppRoutes.arenaDetailCustomer,
                              arguments: arena.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Upcoming Booking Card ──────────────────────────────────────────────────────

class _UpcomingCard extends StatelessWidget {
  final BookingModel booking;
  const _UpcomingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('MMM d').format(booking.startDateTime);
    final timeStr =
        DateFormat('HH:mm').format(booking.startDateTime);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.primary, width: 2),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONFIRMED BOOKING',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking.arenaName,
                    style: AppTextStyles.titleLarge.copyWith(
                      fontSize: 17,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.elevated,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: AppColors.success, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BookingInfoTile(
                  icon: Icons.stadium_outlined,
                  label: 'COURT',
                  value: booking.courtName,
                ),
              ),
              Expanded(
                child: _BookingInfoTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'DATE & TIME',
                  value: '$dateStr · $timeStr',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Get.offAllNamed(AppRoutes.customerDashboard, arguments: 1),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              child: Text(
                'VIEW DIGITAL TICKET',
                style: AppTextStyles.label.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _BookingInfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;
  const _SectionHeader({required this.title, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 4, height: 20, color: AppColors.secondary),
            const SizedBox(width: 10),
            Text(
              title,
              style: AppTextStyles.titleLarge.copyWith(
                fontSize: 17,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: onViewAll,
          child: Text(
            'VIEW ALL',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Featured Card ──────────────────────────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  final ArenaModel arena;
  const _FeaturedCard({required this.arena});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Get.toNamed(AppRoutes.arenaDetailCustomer, arguments: arena.id),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: AppColors.elevated,
          border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ArenaImage(
                  path: arena.images.isNotEmpty ? arena.images.first : null,
                  height: 140,
                  width: 200,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: arena.reviewCount == 0
                        ? Text(
                            'New',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star,
                                  size: 12, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Text(
                                arena.rating.toStringAsFixed(1),
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Obx(() {
                    if (!Get.isRegistered<FavoritesController>()) {
                      return const SizedBox.shrink();
                    }
                    final fc = FavoritesController.to;
                    final fav = fc.isFav(arena.id);
                    return GestureDetector(
                      onTap: () => fc.toggle(arena.id),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          fav ? Icons.favorite : Icons.favorite_border,
                          color: fav
                              ? AppColors.error
                              : AppColors.textSecondary,
                          size: 15,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    arena.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.near_me_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          arena.location.displayAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'PKR ${arena.minPrice.toStringAsFixed(0)}',
                              style: AppTextStyles.scoreboard.copyWith(
                                fontSize: 15,
                                color: AppColors.primary,
                              ),
                            ),
                            TextSpan(
                              text: '/hr',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textSecondary, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Nearby Card ────────────────────────────────────────────────────────────────

class _NearbyCard extends StatelessWidget {
  final ArenaModel arena;
  const _NearbyCard({required this.arena});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Get.toNamed(AppRoutes.arenaDetailCustomer, arguments: arena.id),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: AppColors.elevated,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Stack(
                children: [
                  ArenaImage(
                    path: arena.images.isNotEmpty ? arena.images.first : null,
                    height: 180,
                    width: double.infinity,
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: arena.reviewCount == 0
                          ? Text(
                              'New',
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star,
                                    size: 13, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  arena.rating.toStringAsFixed(1),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Obx(() {
                      if (!Get.isRegistered<FavoritesController>()) {
                        return const SizedBox.shrink();
                      }
                      final fc = FavoritesController.to;
                      final fav = fc.isFav(arena.id);
                      return GestureDetector(
                        onTap: () => fc.toggle(arena.id),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            fav ? Icons.favorite : Icons.favorite_border,
                            color: fav
                                ? AppColors.error
                                : AppColors.textSecondary,
                            size: 18,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
              // Info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            arena.name,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontSize: 16,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 13, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${DiscoveryController.to.distanceOf(arena).toStringAsFixed(1)} KM AWAY',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'PKR ${arena.minPrice.toStringAsFixed(0)}',
                            style: AppTextStyles.scoreboard.copyWith(
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                          TextSpan(
                            text: '/hr',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quick Filter Row ───────────────────────────────────────────────────────────

void showDiscoveryFilterSheet(BuildContext context, DiscoveryController d) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FilterSheet(discovery: d),
  );
}

class _QuickFilterRow extends StatelessWidget {
  final DiscoveryController discovery;
  const _QuickFilterRow({required this.discovery});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Obx(() => Row(
              children: [
                _QuickChip(
                  label: 'All',
                  selected: discovery.typeFilter.value == null,
                  onTap: () => discovery.typeFilter.value = null,
                ),
                const SizedBox(width: 8),
                ...CourtType.values.map((t) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _QuickChip(
                    label: t.label,
                    selected: discovery.typeFilter.value == t,
                    onTap: () => discovery.typeFilter.value =
                        discovery.typeFilter.value == t ? null : t,
                  ),
                )),
              ],
            )),
          ),
        ),
        const SizedBox(width: 8),
        Obx(() {
          final count = discovery.activeFilterCount;
          return GestureDetector(
            onTap: () => showDiscoveryFilterSheet(context, discovery),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: count > 0
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.elevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: count > 0 ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune,
                    size: 16,
                    color: count > 0 ? AppColors.primary : AppColors.textSecondary,
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _QuickChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.elevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.onPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Filter Bottom Sheet ────────────────────────────────────────────────────────

class _FilterSheet extends StatelessWidget {
  final DiscoveryController discovery;
  const _FilterSheet({required this.discovery});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.textSecondary,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filters',
                      style: AppTextStyles.titleLarge.copyWith(
                          fontSize: 18, color: AppColors.textPrimary)),
                  Obx(() => discovery.activeFilterCount > 0
                      ? GestureDetector(
                          onTap: () {
                            discovery.clearFilters();
                            Navigator.pop(context);
                          },
                          child: Text('Reset All',
                              style: AppTextStyles.label.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        )
                      : const SizedBox.shrink()),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: AppColors.border),
            ),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  _fsSection(
                    'SORT BY',
                    Obx(() => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: SortBy.values
                          .map((s) => _SheetChip(
                                label: s.label,
                                selected: discovery.sortBy.value == s,
                                onTap: () => discovery.sortBy.value = s,
                              ))
                          .toList(),
                    )),
                  ),
                  _fsSection(
                    'SPORT TYPE',
                    Obx(() => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SheetChip(
                          label: 'All',
                          selected: discovery.typeFilter.value == null,
                          onTap: () => discovery.typeFilter.value = null,
                        ),
                        ...CourtType.values.map((t) => _SheetChip(
                              label: t.label,
                              selected: discovery.typeFilter.value == t,
                              onTap: () => discovery.typeFilter.value =
                                  discovery.typeFilter.value == t ? null : t,
                            )),
                      ],
                    )),
                  ),
                  _fsSection(
                    'SURFACE',
                    Obx(() => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SheetChip(
                          label: 'Any',
                          selected: discovery.surfaceFilter.value == null,
                          onTap: () => discovery.surfaceFilter.value = null,
                        ),
                        ...CourtSurface.values.map((s) => _SheetChip(
                              label: s.label,
                              selected: discovery.surfaceFilter.value == s,
                              onTap: () => discovery.surfaceFilter.value =
                                  discovery.surfaceFilter.value == s
                                      ? null
                                      : s,
                            )),
                      ],
                    )),
                  ),
                  _fsSection(
                    'MIN RATING',
                    Obx(() => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SheetChip(
                          label: 'Any',
                          selected: discovery.minRating.value == 0,
                          onTap: () => discovery.minRating.value = 0,
                        ),
                        ...[1, 2, 3, 4].map((r) => _SheetChip(
                              label: '$r★+',
                              selected:
                                  discovery.minRating.value == r.toDouble(),
                              onTap: () => discovery.minRating.value =
                                  discovery.minRating.value == r.toDouble()
                                      ? 0
                                      : r.toDouble(),
                            )),
                      ],
                    )),
                  ),
                  _fsSection(
                    'MAX PRICE',
                    Obx(() => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Up to',
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                            Text(
                              'PKR ${discovery.maxPrice.value.toStringAsFixed(0)}',
                              style: AppTextStyles.label.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: AppColors.primary,
                            inactiveTrackColor: AppColors.border,
                            thumbColor: AppColors.primary,
                            overlayColor:
                                AppColors.primary.withValues(alpha: 0.18),
                            trackHeight: 3,
                          ),
                          child: Slider(
                            value: discovery.maxPrice.value,
                            min: 500,
                            max: 10000,
                            divisions: 19,
                            onChanged: (v) =>
                                discovery.maxPrice.value = v,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('PKR 500',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11)),
                            Text('PKR 10,000',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11)),
                          ],
                        ),
                      ],
                    )),
                  ),
                  _fsSection(
                    'AMENITIES',
                    Obx(() => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SheetChip(
                          label: 'Any',
                          selected: discovery.amenityFilter.value == null,
                          onTap: () => discovery.amenityFilter.value = null,
                        ),
                        ...CourtAmenity.values.map((a) => _SheetChip(
                              label: a.label,
                              selected: discovery.amenityFilter.value == a,
                              onTap: () => discovery.amenityFilter.value =
                                  discovery.amenityFilter.value == a
                                      ? null
                                      : a,
                            )),
                      ],
                    )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fsSection(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SheetChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.onPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Secondary CTA Button ───────────────────────────────────────────────────────

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SecondaryButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        color: AppColors.primary,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.button.copyWith(
                fontSize: 11,
                letterSpacing: 1.4,
                color: AppColors.onPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(icon, size: 16, color: AppColors.onPrimary),
          ],
        ),
      ),
    );
  }
}
