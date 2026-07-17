import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/owner_booking_controller.dart';
import '../../controllers/owner_controller.dart';
import '../../data/models/arena_model.dart';
import '../../data/models/boost_request_model.dart';
import '../../data/models/booking_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/arena_image.dart';

const _bg = Color(0xFF10131A);
const _surface = Color(0xFF1D2026);
const _surfaceLow = Color(0xFF191C22);
const _outline = Color(0xFF3B494B);
const _cyan = Color(0xFF00DBE9);
const _greenFixed = Color(0xFF79FF5B);
const _amber = Color(0xFFFFB59C);
const _red = Color(0xFFFFB4AB);
const _onSurface = Color(0xFFE1E2EB);
const _onSurfaceVar = Color(0xFFB9CACB);

enum _Filter { all, approved, pending, inactive }

String _fmtRevenue(double v) {
  if (v >= 100000) {
    final lakhs = v / 100000;
    return '${lakhs.toStringAsFixed(lakhs.truncateToDouble() == lakhs ? 0 : 2)}L';
  }
  return NumberFormat('#,##0').format(v);
}

/// Owner's arenas list tab with live stats, status filters and search.
class MyArenasScreen extends StatelessWidget {
  const MyArenasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final owner = OwnerController.to;
    final showSearch = false.obs;
    final query = ''.obs;
    final filter = _Filter.all.obs;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('My Arenas',
                      style: TextStyle(
                          color: _onSurface, fontSize: 22, fontWeight: FontWeight.w800)),
                  Row(
                    children: [
                      Obx(() => IconButton(
                            onPressed: () => showSearch.value = !showSearch.value,
                            icon: Icon(showSearch.value ? Icons.close : Icons.search,
                                color: _onSurface),
                          )),
                      IconButton(
                        style: IconButton.styleFrom(backgroundColor: _greenFixed),
                        icon: const Icon(Icons.add, color: Color(0xFF0B0E14)),
                        onPressed: () => Get.toNamed(AppRoutes.addArena),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Obx(() => showSearch.value
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => query.value = v,
                      style: const TextStyle(color: _onSurface),
                      decoration: InputDecoration(
                        hintText: 'Search arenas…',
                        hintStyle: const TextStyle(color: _onSurfaceVar),
                        prefixIcon: const Icon(Icons.search, color: _onSurfaceVar),
                        filled: true,
                        fillColor: _surfaceLow,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _cyan),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink()),
            Obx(() {
              final all = owner.myArenas;
              final total = all.length;
              final active = all
                  .where((a) => a.status == ArenaStatus.approved && a.isActive)
                  .length;
              final pending = all.where((a) => a.status == ArenaStatus.pending).length;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    _statPill('$total', 'TOTAL', _onSurfaceVar),
                    const SizedBox(width: 10),
                    _statPill('$active', 'ACTIVE', _greenFixed),
                    const SizedBox(width: 10),
                    _statPill('$pending', 'PENDING', _amber),
                  ],
                ),
              );
            }),
            SizedBox(
              height: 36,
              child: Obx(() => ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _filterChip('All', _Filter.all, filter),
                      _filterChip('Approved', _Filter.approved, filter),
                      _filterChip('Pending', _Filter.pending, filter),
                      _filterChip('Inactive', _Filter.inactive, filter),
                    ],
                  )),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Obx(() {
                OwnerBookingController.to.bookings.length; // rebuild on booking changes
                var items = owner.myArenas.toList();
                switch (filter.value) {
                  case _Filter.all:
                    break;
                  case _Filter.approved:
                    items = items.where((a) => a.status == ArenaStatus.approved).toList();
                    break;
                  case _Filter.pending:
                    items = items.where((a) => a.status == ArenaStatus.pending).toList();
                    break;
                  case _Filter.inactive:
                    items = items.where((a) => !a.isActive).toList();
                    break;
                }
                if (query.value.trim().isNotEmpty) {
                  final q = query.value.trim().toLowerCase();
                  items = items.where((a) => a.name.toLowerCase().contains(q)).toList();
                }
                if (items.isEmpty) return _emptyState(owner.myArenas.isEmpty);
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (_, i) => _arenaCard(items[i]),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: _onSurfaceVar, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _Filter value, Rx<_Filter> filter) {
    final selected = filter.value == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => filter.value = value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _cyan : _surfaceLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? _cyan : _outline),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  color: selected ? const Color(0xFF0B0E14) : _onSurfaceVar,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _arenaCard(ArenaModel arena) {
    final pending = arena.status == ArenaStatus.pending;
    final rejectedLike =
        arena.status == ArenaStatus.rejected || arena.status == ArenaStatus.suspended;
    final bookings =
        OwnerBookingController.to.bookings.where((b) => b.arenaId == arena.id).toList();
    final revenue = bookings
        .where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.completed)
        .fold(0.0, (acc, b) => acc + b.totalAmount);

    final Color badgeColor = pending
        ? _amber
        : rejectedLike
            ? _red
            : (arena.isActive ? _greenFixed : _onSurfaceVar);
    final String badgeLabel = pending
        ? 'PENDING'
        : rejectedLike
            ? arena.status.name.toUpperCase()
            : (arena.isActive ? 'ACTIVE' : 'INACTIVE');

    return Container(
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pending ? _amber.withValues(alpha: 0.5) : _outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Get.toNamed(AppRoutes.arenaDetailOwner, arguments: arena.id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ArenaImage(
                    path: arena.images.isNotEmpty ? arena.images.first : null,
                    height: 150,
                    width: double.infinity,
                    borderRadius: BorderRadius.zero,
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(pending ? Icons.hourglass_empty : Icons.circle,
                              size: pending ? 12 : 8, color: const Color(0xFF0B0E14)),
                          const SizedBox(width: 5),
                          Text(badgeLabel,
                              style: const TextStyle(
                                  color: Color(0xFF0B0E14),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  if (arena.isFeatured)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _cyan,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('⚡ BOOSTED',
                            style: TextStyle(
                                color: Color(0xFF0B0E14),
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  if (pending)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _bg.withValues(alpha: 0.75),
                          border: const Border(top: BorderSide(color: _amber, width: 1.5)),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Awaiting Admin Approval',
                            style: TextStyle(
                                color: _amber, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _onSurface, fontSize: 17, fontWeight: FontWeight.w800)),
                        ),
                        if (!pending && !rejectedLike)
                          Switch(
                            value: arena.isActive,
                            activeThumbColor: _greenFixed,
                            onChanged: (_) => OwnerController.to.toggleArenaActive(arena.id),
                          ),
                      ],
                    ),
                    if (arena.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(arena.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _onSurfaceVar, fontSize: 13)),
                      ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _outline),
                      ),
                      child: Row(
                        children: [
                          _statColumn('Courts', '${arena.courts.length}', _onSurface),
                          _vDivider(),
                          _statColumn('Bookings', '${bookings.length}', _onSurface),
                          _vDivider(),
                          _statColumn('Revenue', _fmtRevenue(revenue), _greenFixed),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _cardButton(
                            'View',
                            outline: true,
                            onTap: () => Get.toNamed(AppRoutes.arenaDetailOwner,
                                arguments: arena.id),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _cardButton(
                            'Edit',
                            outline: true,
                            onTap: () =>
                                Get.toNamed(AppRoutes.editArena, arguments: arena.id),
                          ),
                        ),
                        if (!pending && !rejectedLike) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: _cardButton(
                              'Boost',
                              filled: true,
                              onTap: () => Get.toNamed(
                                AppRoutes.boostRequest,
                                arguments: {
                                  'arenaId': arena.id,
                                  'arenaName': arena.name,
                                  'type': BoostType.boost,
                                },
                              ),
                            ),
                          ),
                        ] else if (pending) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: _cardButton(
                              'Check Status',
                              outline: true,
                              muted: true,
                              onTap: () => Get.toNamed(AppRoutes.arenaDetailOwner,
                                  arguments: arena.id),
                            ),
                          ),
                        ],
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

  Widget _statColumn(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: _onSurfaceVar, fontSize: 11.5)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(color: valueColor, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 28, color: _outline);

  Widget _cardButton(String label,
      {bool outline = false, bool filled = false, bool muted = false, VoidCallback? onTap}) {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: filled ? _greenFixed : Colors.transparent,
          foregroundColor: filled
              ? const Color(0xFF0B0E14)
              : (muted ? _onSurfaceVar : _onSurface),
          side: BorderSide(color: filled ? _greenFixed : _outline),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 13, fontWeight: filled ? FontWeight.w800 : FontWeight.w600)),
      ),
    );
  }

  Widget _emptyState(bool noArenasAtAll) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.stadium_outlined, size: 72, color: _onSurfaceVar),
          const SizedBox(height: 16),
          Text(noArenasAtAll ? 'No arenas yet' : 'No arenas match this filter',
              style: const TextStyle(color: _onSurface, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            noArenasAtAll ? 'Tap + to add your first arena' : 'Try a different filter or search',
            style: const TextStyle(color: _onSurfaceVar, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
