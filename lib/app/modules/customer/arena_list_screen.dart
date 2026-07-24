import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/discovery_controller.dart';
import '../../data/models/arena_model.dart';
import '../../data/models/court_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/arena_image.dart';
import 'arena_map_view_screen.dart';
import 'home_tab.dart' show showDiscoveryFilterSheet;

class ArenaListScreen extends StatelessWidget {
  const ArenaListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final discovery = DiscoveryController.to;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final DiscoveryController discovery;
  const _Header({required this.discovery});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _SquareButton(icon: Icons.arrow_back, onTap: Get.back),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Find Arenas',
                style: AppTextStyles.headlineMedium.copyWith(color: onSurface)),
          ),
          Obx(() => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${discovery.searchRadius.value.toStringAsFixed(0)}km',
                  style: AppTextStyles.label.copyWith(color: Colors.white),
                ),
              )),
          const SizedBox(width: 10),
          Obx(() => _SquareButton(
                icon: discovery.isMapView.value
                    ? Icons.format_list_bulleted
                    : Icons.map_outlined,
                onTap: discovery.toggleMapView,
              )),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SquareButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.secondary, size: 22),
      ),
    );
  }
}

// ── List body ────────────────────────────────────────────────────────────────

class _ListBody extends StatelessWidget {
  final DiscoveryController discovery;
  const _ListBody({required this.discovery});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;
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
                      style: AppTextStyles.bodySmall.copyWith(color: muted),
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
                child: CircularProgressIndicator(color: AppColors.secondary),
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

// ── Search field ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final DiscoveryController discovery;
  const _SearchField({required this.discovery});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = theme.textTheme.bodySmall?.color;
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerTheme.color ?? AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: muted, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (v) => discovery.searchQuery.value = v,
              style: AppTextStyles.bodyMedium.copyWith(color: onSurface),
              cursorColor: AppColors.secondary,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search arenas…',
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: muted),
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
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Obx(() => Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.tune,
                          color: AppColors.secondary, size: 20),
                      if (discovery.activeFilterCount > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
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

// ── Sport chips ───────────────────────────────────────────────────────────────

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
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.secondary.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 17,
                color: selected ? AppColors.onPrimary : AppColors.secondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: selected ? AppColors.onPrimary : AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sort button ───────────────────────────────────────────────────────────────

class _SortButton extends StatelessWidget {
  final DiscoveryController discovery;
  const _SortButton({required this.discovery});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _showSortSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerTheme.color ?? AppColors.border),
        ),
        child: Row(
          children: [
            Text('Sort',
                style: AppTextStyles.label
                    .copyWith(color: AppColors.secondary)),
            const SizedBox(width: 4),
            const Icon(Icons.unfold_more,
                color: AppColors.secondary, size: 16),
          ],
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
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
                    color: theme.dividerTheme.color ?? AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Sort by',
                  style: AppTextStyles.titleLarge.copyWith(color: onSurface)),
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
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: selected ? AppColors.primary : onSurface,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_circle,
                            color: AppColors.primary, size: 20)
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

// ── Arena grid card ───────────────────────────────────────────────────────────

class _ArenaGridCard extends StatelessWidget {
  final ArenaModel arena;
  const _ArenaGridCard({required this.arena});

  @override
  Widget build(BuildContext context) {
    final discovery = DiscoveryController.to;
    final dist = discovery.distanceOf(arena);
    final sport =
        arena.courts.isNotEmpty ? arena.courts.first.type : CourtType.other;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = theme.textTheme.bodySmall?.color;

    return GestureDetector(
      onTap: () =>
          Get.toNamed(AppRoutes.arenaDetailCustomer, arguments: arena.id),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerTheme.color ?? AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + overlays
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(19)),
              child: Stack(
                children: [
                  ArenaImage(
                    path: arena.images.isNotEmpty ? arena.images.first : null,
                    height: 150,
                    width: double.infinity,
                  ),
                  // Bottom fade into secondary
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
                            AppColors.secondary.withValues(alpha: 0.75),
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
                      color: AppColors.secondary,
                      child: Text(
                        '${dist.toStringAsFixed(1)} km',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
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
                        color: const Color(0xCC0B0E11),
                        child: Text(
                          'FEATURED',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  // Sport chip
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: _pill(
                      color: AppColors.secondary,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_SportChipsRow._iconFor(sport),
                              size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            sport.label,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
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
                    style: AppTextStyles.titleMedium.copyWith(color: onSurface),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 13, color: muted),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          arena.location.displayAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(color: muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (arena.reviewCount == 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.elevated,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'New',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else ...[
                        const Icon(Icons.star,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Text(
                          '${arena.rating.toStringAsFixed(1)} (${arena.reviewCount})',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Flexible(
                        child: Text(
                          'PKR ${arena.minPrice.toStringAsFixed(0)}/hr',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.scoreboard.copyWith(
                            color: AppColors.primary,
                            fontSize: 13,
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

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final DiscoveryController discovery;
  const _EmptyState({required this.discovery});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = theme.textTheme.bodySmall?.color;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: muted),
            const SizedBox(height: 16),
            Obx(() => Text(
                  'No arenas within ${discovery.searchRadius.value.toStringAsFixed(0)} km',
                  style: AppTextStyles.titleLarge.copyWith(color: onSurface),
                  textAlign: TextAlign.center,
                )),
            const SizedBox(height: 8),
            Text(
              "We couldn't find any arenas matching your filters.",
              style: AppTextStyles.bodyMedium.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Obx(() {
              if (discovery.searchRadius.value < 50) {
                return ElevatedButton.icon(
                  icon: const Icon(Icons.expand_outlined),
                  label: const Text('Expand search to 50 km'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
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
              child: Text(
                'Clear filters & reset radius',
                style:
                    AppTextStyles.label.copyWith(color: AppColors.secondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
