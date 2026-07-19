import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/discovery_controller.dart';
import '../../data/models/arena_model.dart';
import '../../data/models/court_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/arena_image.dart';
import 'arena_map_view_screen.dart';
import 'home_tab.dart' show showDiscoveryFilterSheet;

class ArenaListScreen extends StatelessWidget {
  const ArenaListScreen({super.key});

  // Palette tuned to the deep-navy discovery design
  static const bg = Color(0xFF0A1120);
  static const surface = Color(0xFF121B2E);
  static const surfaceHigh = Color(0xFF1A2440);
  static const outline = Color(0xFF223052);
  static const blue = Color(0xFF2979FF);
  static const green = Color(0xFF00E676);
  static const grey = Color(0xFF8A94A6);

  @override
  Widget build(BuildContext context) {
    final discovery = DiscoveryController.to;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(discovery: discovery),
            Expanded(
              child: Obx(() {
                if (discovery.isMapView.value) {
                  return const ArenaMapViewScreen();
                }
                return _ListBody(discovery: discovery);
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header: back • title • radius • map toggle ───────────────────────────────

class _Header extends StatelessWidget {
  final DiscoveryController discovery;
  const _Header({required this.discovery});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _SquareButton(
            icon: Icons.arrow_back,
            iconColor: ArenaListScreen.blue,
            onTap: Get.back,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Find Arenas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Obx(() => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: ArenaListScreen.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${discovery.searchRadius.value.toStringAsFixed(0)}km',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )),
          const SizedBox(width: 10),
          Obx(() => _SquareButton(
                icon: discovery.isMapView.value
                    ? Icons.format_list_bulleted
                    : Icons.map_outlined,
                iconColor: ArenaListScreen.blue,
                onTap: discovery.toggleMapView,
              )),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  const _SquareButton({
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: ArenaListScreen.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

// ── List body: search • chips • count/sort • grid ────────────────────────────

class _ListBody extends StatelessWidget {
  final DiscoveryController discovery;
  const _ListBody({required this.discovery});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _SearchField(discovery: discovery),
        ),
        const SizedBox(height: 14),
        _SportChipsRow(discovery: discovery),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Obx(() => Text(
                      '${discovery.nearby.length} arenas found nearby',
                      style: const TextStyle(
                        color: ArenaListScreen.grey,
                        fontSize: 14,
                      ),
                    )),
              ),
              _SortButton(discovery: discovery),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Obx(() {
            if (discovery.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(color: ArenaListScreen.blue),
              );
            }
            final list = discovery.nearby;
            if (list.isEmpty) {
              return _EmptyState(discovery: discovery);
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                mainAxisExtent: 258,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) => _ArenaGridCard(arena: list[i]),
            );
          }),
        ),
      ],
    );
  }
}

// ── Search field with filter button ──────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final DiscoveryController discovery;
  const _SearchField({required this.discovery});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: BoxDecoration(
        color: ArenaListScreen.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ArenaListScreen.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: ArenaListScreen.grey, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (v) => discovery.searchQuery.value = v,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: ArenaListScreen.blue,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search arenas…',
                hintStyle:
                    TextStyle(color: ArenaListScreen.grey, fontSize: 15),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => showDiscoveryFilterSheet(context, discovery),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: ArenaListScreen.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Obx(() => Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.tune,
                          color: ArenaListScreen.blue, size: 20),
                      if (discovery.activeFilterCount > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: ArenaListScreen.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sport type chips ─────────────────────────────────────────────────────────

class _SportChipsRow extends StatelessWidget {
  final DiscoveryController discovery;
  const _SportChipsRow({required this.discovery});

  static IconData _iconFor(CourtType t) {
    switch (t) {
      case CourtType.football:
        return Icons.sports_soccer;
      case CourtType.cricket:
        return Icons.sports_cricket;
      case CourtType.padel:
        return Icons.sports_tennis;
      case CourtType.indoor:
        return Icons.stadium_outlined;
      case CourtType.other:
        return Icons.sports;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Obx(() => ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _SportChip(
                label: 'All',
                icon: Icons.grid_view_rounded,
                selected: discovery.typeFilter.value == null,
                onTap: () => discovery.typeFilter.value = null,
              ),
              ...CourtType.values.map(
                (t) => _SportChip(
                  label: t.label,
                  icon: _iconFor(t),
                  selected: discovery.typeFilter.value == t,
                  onTap: () => discovery.typeFilter.value = t,
                ),
              ),
            ],
          )),
    );
  }
}

class _SportChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _SportChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? ArenaListScreen.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? ArenaListScreen.blue
                : ArenaListScreen.blue.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 17,
                color: selected ? Colors.white : ArenaListScreen.blue),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : ArenaListScreen.blue,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sort button + sheet ──────────────────────────────────────────────────────

class _SortButton extends StatelessWidget {
  final DiscoveryController discovery;
  const _SortButton({required this.discovery});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSortSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: ArenaListScreen.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ArenaListScreen.outline),
        ),
        child: const Row(
          children: [
            Text(
              'Sort',
              style: TextStyle(
                color: ArenaListScreen.blue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.unfold_more, color: ArenaListScreen.blue, size: 16),
          ],
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArenaListScreen.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ArenaListScreen.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sort by',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...SortBy.values.map(
                (s) => Obx(() {
                  final selected = discovery.sortBy.value == s;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      discovery.sortBy.value = s;
                      Navigator.pop(ctx);
                    },
                    title: Text(
                      s.label,
                      style: TextStyle(
                        color:
                            selected ? ArenaListScreen.blue : Colors.white,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_circle,
                            color: ArenaListScreen.blue, size: 20)
                        : null,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Arena grid card ──────────────────────────────────────────────────────────

class _ArenaGridCard extends StatelessWidget {
  final ArenaModel arena;
  const _ArenaGridCard({required this.arena});

  @override
  Widget build(BuildContext context) {
    final discovery = DiscoveryController.to;
    final dist = discovery.distanceOf(arena);
    final sport =
        arena.courts.isNotEmpty ? arena.courts.first.type : CourtType.other;

    return GestureDetector(
      onTap: () =>
          Get.toNamed(AppRoutes.arenaDetailCustomer, arguments: arena.id),
      child: Container(
        decoration: BoxDecoration(
          color: ArenaListScreen.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ArenaListScreen.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with overlays
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
              child: Stack(
                children: [
                  ArenaImage(
                    path: arena.images.isNotEmpty ? arena.images.first : null,
                    height: 150,
                    width: double.infinity,
                  ),
                  // Bottom fade into blue for the sport chip
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            ArenaListScreen.blue.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Distance pill
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _pill(
                      color: ArenaListScreen.blue,
                      child: Text(
                        '${dist.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Featured badge
                  if (arena.isFeatured)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _pill(
                        color: const Color(0xCC0A1120),
                        child: const Text(
                          'FEATURED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  // Sport chip
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: _pill(
                      color: ArenaListScreen.blue,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_SportChipsRow._iconFor(sport),
                              size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            sport.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Text section
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    arena.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: ArenaListScreen.grey),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          arena.location.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ArenaListScreen.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 14, color: ArenaListScreen.green),
                      const SizedBox(width: 3),
                      Text(
                        '${arena.rating.toStringAsFixed(1)} (${arena.reviewCount})',
                        style: const TextStyle(
                          color: ArenaListScreen.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          'PKR ${arena.minPrice.toStringAsFixed(0)}/hr',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ArenaListScreen.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
    );
  }

  Widget _pill({required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

// ── Empty state with 50 km expand ────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final DiscoveryController discovery;
  const _EmptyState({required this.discovery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off,
                size: 64, color: ArenaListScreen.grey),
            const SizedBox(height: 16),
            Obx(() => Text(
                  'No arenas within ${discovery.searchRadius.value.toStringAsFixed(0)} km',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                )),
            const SizedBox(height: 8),
            const Text(
              "We couldn't find any arenas matching your filters.",
              style: TextStyle(color: ArenaListScreen.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Obx(() {
              if (discovery.searchRadius.value < 50) {
                return ElevatedButton.icon(
                  icon: const Icon(Icons.expand_outlined),
                  label: const Text('Expand search to 50 km'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ArenaListScreen.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: discovery.expandTo50km,
                );
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 12),
            TextButton(
              onPressed: discovery.clearFilters,
              child: const Text(
                'Clear filters & reset radius',
                style: TextStyle(color: ArenaListScreen.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
