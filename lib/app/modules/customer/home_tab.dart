import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
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
import '../../widgets/platform_promo_banner.dart';

// ─── palette shorthands ───────────────────────────────────────────────────────
const _bg = AppColors.background;
const _surface = AppColors.surface;
const _elevated = AppColors.elevated;
const _border = AppColors.border;
const _lime = AppColors.primary;
const _blue = AppColors.secondary;
const _text = AppColors.textPrimary;
const _muted = AppColors.textSecondary;
const _onLime = AppColors.onPrimary;
const _red = AppColors.error;
const _green = AppColors.success;

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final discovery = DiscoveryController.to;

    return Container(
      color: _bg,
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Sticky top bar ────────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _TopBarDelegate(discovery: discovery),
            ),

            const SliverToBoxAdapter(child: PlatformPromoBanner()),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search
                    // _SearchBar(),
                    // const SizedBox(height: 12),
                    // Quick filter chips
                    _QuickFilterRow(discovery: discovery),
                    const SizedBox(height: 20),

                    // Skeleton while loading
                    Obx(() {
                      if (!discovery.isLoading.value) {
                        return const SizedBox.shrink();
                      }
                      return const _HomeSkeleton();
                    }),

                    // Promo carousel
                    Obx(() {
                      if (discovery.carousel.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        children: [
                          _PromoBannerCarousel(arenas: discovery.carousel),
                          const SizedBox(height: 28),
                        ],
                      );
                    }),

                    // Upcoming booking
                    Obx(() {
                      if (!Get.isRegistered<BookingController>()) {
                        return const SizedBox.shrink();
                      }
                      final bc = Get.find<BookingController>();
                      if (bc.upcoming.isEmpty) return const SizedBox.shrink();
                      final booking = bc.upcoming.first;
                      final _box = GetStorage();
                      final _key = 'hide_upcoming_${booking.id}';
                      final hidden = RxBool(_box.read<bool>(_key) ?? false);
                      return Obx(
                        () => Column(
                          children: [
                            if (hidden.value)
                              _HiddenUpcomingBanner(
                                onShow: () {
                                  hidden.value = false;
                                  _box.write(_key, false);
                                },
                              )
                            else
                              _UpcomingCard(
                                booking: booking,
                                onHide: () {
                                  hidden.value = true;
                                  _box.write(_key, true);
                                },
                              ),
                            const SizedBox(height: 28),
                          ],
                        ),
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
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 260,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: saved.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (_, i) =>
                                  _FeaturedCard(arena: saved[i]),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      );
                    }),

                    // Featured arenas
                    Obx(() {
                      if (discovery.isLoading.value) {
                        return const SizedBox.shrink();
                      }
                      final featured = discovery.featured;
                      if (featured.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            title: 'Featured Arenas Near You',
                            onViewAll: () => Get.toNamed(AppRoutes.arenaList),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 260,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: featured.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (_, i) =>
                                  _FeaturedCard(arena: featured[i]),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      );
                    }),

                    // Nearby arenas — with grid/list toggle
                    Obx(() {
                      if (discovery.isLoading.value) {
                        return const SizedBox.shrink();
                      }
                      if (discovery.nearby.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return _NearbySection(arenas: discovery.nearby);
                    }),

                    // Empty state
                    Obx(() {
                      if (discovery.isLoading.value) {
                        return const SizedBox.shrink();
                      }
                      final nothing =
                          discovery.carousel.isEmpty &&
                          discovery.featured.isEmpty &&
                          discovery.nearby.isEmpty;
                      if (!nothing) return const SizedBox.shrink();
                      return const _EmptyArenasState();
                    }),
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

// ── Top bar ────────────────────────────────────────────────────────────────────

class _TopBarDelegate extends SliverPersistentHeaderDelegate {
  final DiscoveryController discovery;
  const _TopBarDelegate({required this.discovery});

  @override
  double get minExtent => 68;
  @override
  double get maxExtent => 68;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Location pill
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT HUB',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 2),
                Obx(
                  () => Row(
                    children: [
                      const Icon(Icons.location_on, color: _blue, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        discovery.cityName.value,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 14,
                          color: _text,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _muted,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Brand
          Text(
            'ArenaPro',
            style: AppTextStyles.titleLarge.copyWith(
              fontSize: 18,
              color: _lime,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 14),

          // Bell
          GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.notifications),
            child: Obx(() {
              final unread = NotificationController.to.unreadCount;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _elevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: _border.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: _muted,
                      size: 20,
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _red,
                          shape: BoxShape.circle,
                          border: Border.all(color: _bg, width: 1.5),
                        ),
                        child: Center(
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
                    ),
                ],
              );
            }),
          ),
          const SizedBox(width: 8),

          // Search
          GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.arenaList),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _elevated,
                shape: BoxShape.circle,
                border: Border.all(color: _border.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.search, color: _muted, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TopBarDelegate old) => false;
}

// ── Search bar ─────────────────────────────────────────────────────────────────

// class _SearchBar extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () => Get.toNamed(AppRoutes.arenaList),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//         decoration: BoxDecoration(
//           color: _elevated,
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(color: _border.withValues(alpha: 0.5)),
//         ),
//         child: Row(
//           children: [
//             const Icon(Icons.search, color: _muted, size: 20),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Text(
//                 'Search sports, arenas, or events…',
//                 style: AppTextStyles.bodyMedium.copyWith(
//                   color: _muted,
//                   fontSize: 14,
//                 ),
//               ),
//             ),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//               decoration: BoxDecoration(
//                 color: _lime.withValues(alpha: 0.12),
//                 borderRadius: BorderRadius.circular(6),
//               ),
//               child: const Icon(Icons.tune_rounded, color: _lime, size: 16),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;
  final Widget? trailing;
  const _SectionHeader({
    required this.title,
    required this.onViewAll,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: _lime,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.titleLarge.copyWith(
              fontSize: 17,
              color: _text,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (trailing case final t?) t,
        GestureDetector(
          onTap: onViewAll,
          child: Text(
            'VIEW ALL',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: _blue,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Featured card (horizontal scroll) ─────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  final ArenaModel arena;
  const _FeaturedCard({required this.arena});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Get.toNamed(AppRoutes.arenaDetailCustomer, arguments: arena.id),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: _elevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + overlays
            SizedBox(
              height: 155,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ArenaImage(
                    path: arena.images.isNotEmpty ? arena.images.first : null,
                    height: 155,
                    width: 220,
                  ),
                  // Gradient overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                  // Heart
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Obx(() {
                      if (!Get.isRegistered<FavoritesController>()) {
                        return const SizedBox.shrink();
                      }
                      final fc = FavoritesController.to;
                      final fav = fc.isFav(arena.id);
                      return GestureDetector(
                        onTap: () => fc.toggle(arena.id),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _bg.withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            fav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: fav ? _red : _muted,
                            size: 16,
                          ),
                        ),
                      );
                    }),
                  ),
                  // Rating / New badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _bg.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: arena.reviewCount == 0
                          ? const Text(
                              'NEW',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: _lime,
                                letterSpacing: 1,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: _lime,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  arena.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _text,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      arena.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _text,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.near_me_outlined,
                          size: 11,
                          color: _muted,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            arena.location.displayAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: _muted),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text:
                                    'PKR ${arena.minPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _lime,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const TextSpan(
                                text: '/hr',
                                style: TextStyle(fontSize: 10, color: _muted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: _lime,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: _onLime,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
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

// ── Nearby section with grid/list toggle ───────────────────────────────────────

class _NearbySection extends StatefulWidget {
  final List<ArenaModel> arenas;
  const _NearbySection({required this.arenas});

  @override
  State<_NearbySection> createState() => _NearbySectionState();
}

class _NearbySectionState extends State<_NearbySection> {
  bool _gridView = true; // default: 2-col grid

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Nearby Arenas',
          onViewAll: () => Get.toNamed(AppRoutes.arenaList),
          trailing: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _ViewToggle(
              gridView: _gridView,
              onToggle: (v) => setState(() => _gridView = v),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_gridView)
          _NearbyGrid(arenas: widget.arenas)
        else
          _NearbyList(arenas: widget.arenas),
      ],
    );
  }
}

// ── View toggle ────────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final bool gridView;
  final ValueChanged<bool> onToggle;
  const _ViewToggle({required this.gridView, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
            icon: Icons.grid_view_rounded,
            active: gridView,
            onTap: () => onToggle(true),
            isLeft: true,
          ),
          _ToggleBtn(
            icon: Icons.view_agenda_rounded,
            active: !gridView,
            onTap: () => onToggle(false),
            isLeft: false,
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final bool isLeft;
  const _ToggleBtn({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _lime : Colors.transparent,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isLeft ? 7 : 0),
            bottomLeft: Radius.circular(isLeft ? 7 : 0),
            topRight: Radius.circular(isLeft ? 0 : 7),
            bottomRight: Radius.circular(isLeft ? 0 : 7),
          ),
        ),
        child: Icon(icon, size: 16, color: active ? _onLime : _muted),
      ),
    );
  }
}

// ── Nearby 2-column grid ───────────────────────────────────────────────────────

class _NearbyGrid extends StatelessWidget {
  final List<ArenaModel> arenas;
  const _NearbyGrid({required this.arenas});

  @override
  Widget build(BuildContext context) {
    // Build pairs for 2-col rows
    final rows = <List<ArenaModel>>[];
    for (var i = 0; i < arenas.length; i += 2) {
      rows.add([arenas[i], if (i + 1 < arenas.length) arenas[i + 1]]);
    }
    return Column(
      children: rows
          .map(
            (pair) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(child: _NearbyGridCard(arena: pair[0])),
                  const SizedBox(width: 10),
                  if (pair.length > 1)
                    Expanded(child: _NearbyGridCard(arena: pair[1]))
                  else
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _NearbyGridCard extends StatelessWidget {
  final ArenaModel arena;
  const _NearbyGridCard({required this.arena});

  @override
  Widget build(BuildContext context) {
    final tags = [
      ...arena.summaryTypes.take(1),
      ...arena.summarySurfaces.take(1),
    ];

    return GestureDetector(
      onTap: () =>
          Get.toNamed(AppRoutes.arenaDetailCustomer, arguments: arena.id),
      child: Container(
        decoration: BoxDecoration(
          color: _elevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            SizedBox(
              height: 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ArenaImage(
                    path: arena.images.isNotEmpty ? arena.images.first : null,
                    height: 110,
                    width: double.infinity,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  // Fav
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Obx(() {
                      if (!Get.isRegistered<FavoritesController>()) {
                        return const SizedBox.shrink();
                      }
                      final fc = FavoritesController.to;
                      final fav = fc.isFav(arena.id);
                      return GestureDetector(
                        onTap: () => fc.toggle(arena.id),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: _bg.withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            fav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: fav ? _red : _muted,
                            size: 13,
                          ),
                        ),
                      );
                    }),
                  ),
                  // Rating
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _bg.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: arena.reviewCount == 0
                          ? const Text(
                              'NEW',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: _lime,
                                letterSpacing: 0.8,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 10,
                                  color: _lime,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  arena.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: _text,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    arena.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _text,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 10, color: _muted),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          arena.location.displayAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: _muted),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${DiscoveryController.to.distanceOf(arena).toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: tags.map((t) => _SportTag(label: t)).toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'PKR ${arena.minPrice.toStringAsFixed(0)}/hr',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _lime,
                      letterSpacing: -0.2,
                    ),
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

// ── Nearby 1-column list ───────────────────────────────────────────────────────

class _NearbyList extends StatelessWidget {
  final List<ArenaModel> arenas;
  const _NearbyList({required this.arenas});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: arenas
          .map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _NearbyListCard(arena: a),
            ),
          )
          .toList(),
    );
  }
}

class _NearbyListCard extends StatelessWidget {
  final ArenaModel arena;
  const _NearbyListCard({required this.arena});

  @override
  Widget build(BuildContext context) {
    final tags = [
      ...arena.summaryTypes.take(1),
      ...arena.summarySurfaces.take(1),
    ];

    return GestureDetector(
      onTap: () =>
          Get.toNamed(AppRoutes.arenaDetailCustomer, arguments: arena.id),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: _elevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left image — fixed 130×110
            SizedBox(
              width: 110,
              height: 130,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ArenaImage(
                    path: arena.images.isNotEmpty ? arena.images.first : null,
                    height: 130,
                    width: 110,
                  ),
                  if (arena.reviewCount > 0)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _bg.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 10,
                              color: _lime,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              arena.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Right info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            arena.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _text,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const Icon(Icons.more_vert, size: 16, color: _muted),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 11, color: _muted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            arena.location.displayAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: _muted),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _border.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '${DiscoveryController.to.distanceOf(arena).toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: tags.map((t) => _SportTag(label: t)).toList(),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'PKR ${arena.minPrice.toStringAsFixed(0)}/hr',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _lime,
                        letterSpacing: -0.2,
                      ),
                    ),
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

// ── Sport tag chip ─────────────────────────────────────────────────────────────

class _SportTag extends StatelessWidget {
  final String label;
  const _SportTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _muted,
        ),
      ),
    );
  }
}

// ── Promo banner carousel ──────────────────────────────────────────────────────

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
          height: 240,
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
                  color: active ? _lime : _muted.withValues(alpha: 0.4),
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
      onTap: () =>
          Get.toNamed(AppRoutes.arenaDetailCustomer, arguments: arena.id),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 240,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ArenaImage(
                path: arena.images.isNotEmpty ? arena.images.first : null,
                height: 240,
                width: double.infinity,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'FEATURED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      arena.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.near_me_outlined,
                          size: 12,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            arena.location.displayAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        RichText(text: const TextSpan(children: [])),
                        Expanded(
                          child: Text(
                            'PKR ${arena.minPrice.toStringAsFixed(0)}/hr',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _lime,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Get.toNamed(
                            AppRoutes.arenaDetailCustomer,
                            arguments: arena.id,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _lime,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'BOOK NOW',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _onLime,
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: _onLime,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
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

// ── Upcoming booking card ──────────────────────────────────────────────────────

class _UpcomingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onHide;
  const _UpcomingCard({required this.booking, required this.onHide});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d').format(booking.startDateTime);
    final timeStr = DateFormat('HH:mm').format(booking.startDateTime);

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lime.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _lime.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _lime.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'CONFIRMED BOOKING',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: _lime,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      booking.arenaName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _text,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: _green,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onHide,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _elevated,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.visibility_off_outlined,
                        size: 16,
                        color: _muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _elevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.stadium_outlined,
                    label: 'COURT',
                    value: booking.courtName,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: _border.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.calendar_today_outlined,
                    label: 'DATE & TIME',
                    value: '$dateStr · $timeStr',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () =>
                  Get.toNamed(AppRoutes.bookingDetail, arguments: booking.id),
              style: OutlinedButton.styleFrom(
                foregroundColor: _lime,
                side: BorderSide(color: _lime.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'VIEW DIGITAL TICKET',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: _lime,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HiddenUpcomingBanner extends StatelessWidget {
  final VoidCallback onShow;
  const _HiddenUpcomingBanner({required this.onShow});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onShow,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _lime.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.confirmation_number_outlined,
              size: 16,
              color: _lime,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'You have an upcoming booking',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ),
            const Icon(Icons.visibility_outlined, size: 14, color: _lime),
            const SizedBox(width: 4),
            const Text(
              'Show',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _lime,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _muted, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  color: _muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Quick filter row ───────────────────────────────────────────────────────────

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
            child: Obx(
              () => Row(
                children: [
                  _QuickChip(
                    label: 'All',
                    selected: discovery.typeFilter.value == null,
                    onTap: () => discovery.typeFilter.value = null,
                  ),
                  const SizedBox(width: 8),
                  ...CourtType.values.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _QuickChip(
                        label: t.label,
                        selected: discovery.typeFilter.value == t,
                        onTap: () => discovery.typeFilter.value =
                            discovery.typeFilter.value == t ? null : t,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                color: count > 0 ? _lime.withValues(alpha: 0.12) : _elevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: count > 0 ? _lime : _border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: count > 0 ? _lime : _muted,
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _lime,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _onLime,
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
  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _lime : _elevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _lime : _border.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? _onLime : _muted,
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyArenasState extends StatelessWidget {
  const _EmptyArenasState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _elevated,
              shape: BoxShape.circle,
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.stadium_outlined, color: _muted, size: 36),
          ),
          const SizedBox(height: 18),
          const Text(
            'No arenas found',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try adjusting your filters or check back later.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _muted),
          ),
        ],
      ),
    );
  }
}

// ── Filter bottom sheet ────────────────────────────────────────────────────────

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
          color: _elevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _text,
                    ),
                  ),
                  Obx(
                    () => discovery.activeFilterCount > 0
                        ? GestureDetector(
                            onTap: () {
                              discovery.clearFilters();
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Reset All',
                              style: TextStyle(
                                color: _blue,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: _border),
            ),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  _fsSection(
                    'SORT BY',
                    Obx(
                      () => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: SortBy.values
                            .map(
                              (s) => _SheetChip(
                                label: s.label,
                                selected: discovery.sortBy.value == s,
                                onTap: () => discovery.sortBy.value = s,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  _fsSection(
                    'SPORT TYPE',
                    Obx(
                      () => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SheetChip(
                            label: 'All',
                            selected: discovery.typeFilter.value == null,
                            onTap: () => discovery.typeFilter.value = null,
                          ),
                          ...CourtType.values.map(
                            (t) => _SheetChip(
                              label: t.label,
                              selected: discovery.typeFilter.value == t,
                              onTap: () => discovery.typeFilter.value =
                                  discovery.typeFilter.value == t ? null : t,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _fsSection(
                    'SURFACE',
                    Obx(
                      () => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SheetChip(
                            label: 'Any',
                            selected: discovery.surfaceFilter.value == null,
                            onTap: () => discovery.surfaceFilter.value = null,
                          ),
                          ...CourtSurface.values.map(
                            (s) => _SheetChip(
                              label: s.label,
                              selected: discovery.surfaceFilter.value == s,
                              onTap: () => discovery.surfaceFilter.value =
                                  discovery.surfaceFilter.value == s ? null : s,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _fsSection(
                    'MIN RATING',
                    Obx(
                      () => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SheetChip(
                            label: 'Any',
                            selected: discovery.minRating.value == 0,
                            onTap: () => discovery.minRating.value = 0,
                          ),
                          ...[1, 2, 3, 4].map(
                            (r) => _SheetChip(
                              label: '$r★+',
                              selected:
                                  discovery.minRating.value == r.toDouble(),
                              onTap: () => discovery.minRating.value =
                                  discovery.minRating.value == r.toDouble()
                                  ? 0
                                  : r.toDouble(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _fsSection(
                    'MAX PRICE',
                    Obx(
                      () => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Up to',
                                style: TextStyle(color: _muted, fontSize: 13),
                              ),
                              Text(
                                'PKR ${discovery.maxPrice.value.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: _lime,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: _lime,
                              inactiveTrackColor: _border,
                              thumbColor: _lime,
                              overlayColor: _lime.withValues(alpha: 0.18),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: discovery.maxPrice.value,
                              min: 500,
                              max: 10000,
                              divisions: 19,
                              onChanged: (v) => discovery.maxPrice.value = v,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'PKR 500',
                                style: TextStyle(color: _muted, fontSize: 11),
                              ),
                              Text(
                                'PKR 10,000',
                                style: TextStyle(color: _muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  _fsSection(
                    'AMENITIES',
                    Obx(
                      () => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SheetChip(
                            label: 'Any',
                            selected: discovery.amenityFilter.value == null,
                            onTap: () => discovery.amenityFilter.value = null,
                          ),
                          ...CourtAmenity.values.map(
                            (a) => _SheetChip(
                              label: a.label,
                              selected: discovery.amenityFilter.value == a,
                              onTap: () => discovery.amenityFilter.value =
                                  discovery.amenityFilter.value == a ? null : a,
                            ),
                          ),
                        ],
                      ),
                    ),
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
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: _muted,
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
  const _SheetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _lime : _bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? _onLime : _muted,
          ),
        ),
      ),
    );
  }
}

// ── Shimmer skeleton ───────────────────────────────────────────────────────────

class _HomeSkeleton extends StatefulWidget {
  const _HomeSkeleton();

  @override
  State<_HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<_HomeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const Color _base = _elevated;
  static const Color _highlight = Color(0xFF2E3A46);
  static const Color _shine = Color(0xFF3A4856);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  LinearGradient _gradient(double t) {
    final center = -0.5 + t * 2.0;
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [
        _base,
        _base,
        _highlight,
        _shine,
        _highlight,
        _base,
        _base,
      ],
      stops: [
        0.0,
        (center - 0.25).clamp(0.0, 1.0),
        (center - 0.10).clamp(0.0, 1.0),
        center.clamp(0.0, 1.0),
        (center + 0.10).clamp(0.0, 1.0),
        (center + 0.25).clamp(0.0, 1.0),
        1.0,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final grad = _gradient(_ctrl.value);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBox(
              gradient: grad,
              width: double.infinity,
              height: 240,
              radius: 20,
            ),
            const SizedBox(height: 28),
            _SkeletonBox(gradient: grad, width: 140, height: 14),
            const SizedBox(height: 14),
            SizedBox(
              height: 260,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, __) => _SkeletonBox(
                  gradient: grad,
                  width: 220,
                  height: 260,
                  radius: 20,
                ),
              ),
            ),
            const SizedBox(height: 28),
            _SkeletonBox(gradient: grad, width: 120, height: 14),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.78,
              children: List.generate(
                4,
                (_) => _SkeletonBox(
                  gradient: grad,
                  width: double.infinity,
                  height: double.infinity,
                  radius: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final LinearGradient gradient;
  final double width;
  final double height;
  final double radius;
  const _SkeletonBox({
    required this.gradient,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
