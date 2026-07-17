import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/discovery_controller.dart';
import '../../data/models/arena_model.dart';
import '../../data/models/court_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/arena_image.dart';
import '../../widgets/status_badge.dart';
import 'arena_map_view_screen.dart';

class ArenaListScreen extends StatelessWidget {
  const ArenaListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final discovery = DiscoveryController.to;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Arenas'),
        actions: [
          // Radius badge
          Obx(() => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${discovery.searchRadius.value.toStringAsFixed(0)} km',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              )),
          // Map / List toggle
          Obx(() => IconButton(
                tooltip:
                    discovery.isMapView.value ? 'List view' : 'Map view',
                icon: Icon(
                  discovery.isMapView.value
                      ? Icons.format_list_bulleted
                      : Icons.map_outlined,
                ),
                onPressed: discovery.toggleMapView,
              )),
        ],
      ),
      body: Obx(() {
        if (discovery.isMapView.value) {
          return const ArenaMapViewScreen();
        }
        return _ListView(discovery: discovery);
      }),
    );
  }
}

// ── List view ─────────────────────────────────────────────────────────────────

class _ListView extends StatelessWidget {
  final DiscoveryController discovery;
  const _ListView({required this.discovery});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FilterBar(discovery: discovery),
        Expanded(
          child: Obx(() {
            if (discovery.isLoading.value) {
              return const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final list = discovery.nearby;

            if (list.isEmpty) {
              return _EmptyState(discovery: discovery);
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) => _ArenaCard(arena: list[i]),
            );
          }),
        ),
      ],
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
            const Icon(Icons.search_off, size: 64, color: AppColors.textGrey),
            const SizedBox(height: 16),
            Obx(() => Text(
                  'No arenas within ${discovery.searchRadius.value.toStringAsFixed(0)} km',
                  style: AppTextStyles.titleLarge
                      .copyWith(color: AppColors.textGrey),
                  textAlign: TextAlign.center,
                )),
            const SizedBox(height: 8),
            Text(
              "We couldn't find any arenas matching your filters.",
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textGrey),
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
              child: const Text('Clear filters & reset radius'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final DiscoveryController discovery;
  const _FilterBar({required this.discovery});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkSurface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => discovery.searchQuery.value = v,
            decoration: const InputDecoration(
              hintText: 'Search arenas…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Obx(() => Row(
                  children: [
                    _chip(
                      label: 'All',
                      selected: discovery.typeFilter.value == null,
                      onTap: () => discovery.typeFilter.value = null,
                    ),
                    ...CourtType.values.map(
                      (t) => _chip(
                        label: t.label,
                        selected: discovery.typeFilter.value == t,
                        onTap: () => discovery.typeFilter.value = t,
                      ),
                    ),
                  ],
                )),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.textGrey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: selected ? Colors.white : AppColors.textGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Arena card ────────────────────────────────────────────────────────────────

class _ArenaCard extends StatelessWidget {
  final ArenaModel arena;
  const _ArenaCard({required this.arena});

  @override
  Widget build(BuildContext context) {
    final dist = DiscoveryController.to.distanceOf(arena);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: () =>
            Get.toNamed(AppRoutes.arenaDetailCustomer, arguments: arena.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: ArenaImage(
                path: arena.images.isNotEmpty ? arena.images.first : null,
                height: 140,
                width: double.infinity,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(arena.name,
                            style: AppTextStyles.titleLarge),
                      ),
                      if (arena.isFeatured)
                        const StatusBadge(status: 'featured'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.textGrey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        arena.location.address,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textGrey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 14, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        arena.rating.toStringAsFixed(1),
                        style: AppTextStyles.bodySmall
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.near_me_outlined,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${dist.toStringAsFixed(1)} km',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.primary),
                      ),
                      const Spacer(),
                      Text(
                        'PKR ${arena.minPrice.toStringAsFixed(0)}/hr',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.primary),
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
}
