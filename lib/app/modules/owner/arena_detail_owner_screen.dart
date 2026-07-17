import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:maps_launcher/maps_launcher.dart';

import '../../controllers/owner_booking_controller.dart';
import '../../controllers/owner_controller.dart';
import '../../data/models/arena_model.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/boost_request_model.dart';
import '../../data/models/court_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/arena_image.dart';

const _bg = Color(0xFF10131A);
const _surface = Color(0xFF1D2026);
const _surfaceLow = Color(0xFF191C22);
const _outline = Color(0xFF3B494B);
const _cyan = Color(0xFF00DBE9);
const _greenFixed = Color(0xFF79FF5B);
const _amber = Color(0xFFFFB59C);
const _orange = Color(0xFFFF7A45);
const _red = Color(0xFFFFB4AB);
const _onSurface = Color(0xFFE1E2EB);
const _onSurfaceVar = Color(0xFFB9CACB);

String _fmtRevenue(double v) {
  if (v >= 100000) {
    final lakhs = v / 100000;
    return '${lakhs.toStringAsFixed(lakhs.truncateToDouble() == lakhs ? 0 : 2)}L';
  }
  return NumberFormat('#,##0').format(v);
}

IconData _courtIcon(CourtType type) {
  switch (type) {
    case CourtType.football:
      return Icons.sports_soccer;
    case CourtType.padel:
      return Icons.sports_tennis;
    case CourtType.indoor:
      return Icons.stadium_outlined;
    case CourtType.cricket:
      return Icons.sports_cricket;
    case CourtType.other:
      return Icons.sports_outlined;
  }
}

/// Owner view of a single arena: gallery, live status toggle, courts,
/// photos, location and boost CTA.
class ArenaDetailOwnerScreen extends StatelessWidget {
  const ArenaDetailOwnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final owner = OwnerController.to;
    final String arenaId = Get.arguments as String;
    final pageIndex = 0.obs;

    return Scaffold(
      backgroundColor: _bg,
      body: Obx(() {
        final arena = owner.myArenas.firstWhereOrNull((a) => a.id == arenaId);
        if (arena == null) {
          return const Center(
            child:
                Text('Arena not found', style: TextStyle(color: _onSurface)),
          );
        }
        OwnerBookingController.to.bookings.length; // rebuild on booking changes
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
                child: _heroGallery(context, arena, pageIndex)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statusCard(owner, arena),
                    const SizedBox(height: 14),
                    _statsRow(arena),
                    const SizedBox(height: 22),
                    _courtsSection(arena),
                    const SizedBox(height: 22),
                    _photosSection(context, arena),
                    const SizedBox(height: 22),
                    _locationSection(arena),
                    const SizedBox(height: 22),
                    _boostBanner(arena),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _heroGallery(
      BuildContext context, ArenaModel arena, RxInt pageIndex) {
    final types = arena.courts.map((c) => c.type).toSet().toList();
    return SizedBox(
      height: 340,
      child: Stack(
        fit: StackFit.expand,
        children: [
          arena.images.isEmpty
              ? const ArenaImage(
                  path: null,
                  height: 340,
                  width: double.infinity,
                  borderRadius: BorderRadius.zero,
                )
              : PageView.builder(
                  onPageChanged: (i) => pageIndex.value = i,
                  itemCount: arena.images.length,
                  itemBuilder: (_, i) => ArenaImage(
                    path: arena.images[i],
                    height: 340,
                    width: double.infinity,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
          IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC0B0E14), Colors.transparent],
                  stops: [0, 0.35],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xF010131A), Colors.transparent],
                  stops: [0, 0.6],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _glassIconButton(Icons.arrow_back, onTap: Get.back),
                  Row(
                    children: [
                      _glassPillButton(
                        'Edit',
                        Icons.edit_outlined,
                        onTap: () => Get.toNamed(AppRoutes.editArena,
                            arguments: arena.id),
                      ),
                      const SizedBox(width: 8),
                      _glassIconButton(
                        Icons.more_vert,
                        onTap: () => _showMoreMenu(context, arena),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (types.isNotEmpty)
            Positioned(
              left: 12,
              top: 64,
              right: 12,
              child: Wrap(
                spacing: 8,
                children: types.map((t) => _typeTag(t.label)).toList(),
              ),
            ),
          if (arena.images.length > 1)
            Positioned(
              bottom: 74,
              left: 0,
              right: 0,
              child: Obx(() => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(arena.images.length, (i) {
                      final active = pageIndex.value == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? _cyan
                              : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  )),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(arena.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 15, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        arena.location.address.isEmpty
                            ? 'No address set'
                            : arena.location.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassIconButton(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _glassPillButton(String label, IconData icon,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _typeTag(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  void _showMoreMenu(BuildContext context, ArenaModel arena) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                  arena.isActive
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _onSurface),
              title: Text(arena.isActive ? 'Deactivate Arena' : 'Activate Arena',
                  style: const TextStyle(color: _onSurface)),
              onTap: () {
                Get.back();
                OwnerController.to.toggleArenaActive(arena.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: _red),
              title: const Text('Delete Arena', style: TextStyle(color: _red)),
              onTap: () {
                Get.back();
                _confirmDelete(arena);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ArenaModel arena) {
    Get.defaultDialog(
      backgroundColor: _surface,
      title: 'Delete Arena?',
      titleStyle: const TextStyle(color: _onSurface, fontWeight: FontWeight.w800),
      middleText:
          'This permanently removes "${arena.name}" and its courts. This cannot be undone.',
      middleTextStyle: const TextStyle(color: _onSurfaceVar),
      textCancel: 'Cancel',
      textConfirm: 'Delete',
      confirmTextColor: Colors.white,
      buttonColor: _red,
      onConfirm: () async {
        Get.back();
        await OwnerController.to.deleteArena(arena.id);
        Get.back();
        Get.snackbar('Arena Deleted', '${arena.name} has been removed',
            backgroundColor: _surfaceLow, colorText: _onSurface);
      },
    );
  }

  Widget _statusCard(OwnerController owner, ArenaModel arena) {
    final pending = arena.status == ArenaStatus.pending;
    final rejectedLike = arena.status == ArenaStatus.rejected ||
        arena.status == ArenaStatus.suspended;
    final approvedActive = arena.status == ArenaStatus.approved && arena.isActive;

    final Color dotColor = pending
        ? _amber
        : rejectedLike
            ? _red
            : (approvedActive ? _greenFixed : _onSurfaceVar);
    final String badgeLabel = pending
        ? 'PENDING'
        : rejectedLike
            ? arena.status.name.toUpperCase()
            : (approvedActive ? 'LIVE' : 'OFFLINE');
    final String title = pending
        ? 'Pending Approval'
        : rejectedLike
            ? (arena.status == ArenaStatus.rejected ? 'Rejected' : 'Suspended')
            : 'Approved';
    final String subtitle = pending
        ? 'Awaiting admin review'
        : rejectedLike
            ? 'Contact admin for details'
            : (arena.isActive ? 'Visible to customers' : 'Hidden from customers');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, size: 8, color: dotColor),
              const SizedBox(width: 5),
              Text(badgeLabel,
                  style: TextStyle(
                      color: dotColor, fontSize: 11, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: _onSurface, fontSize: 15, fontWeight: FontWeight.w800)),
                Text(subtitle,
                    style: const TextStyle(color: _onSurfaceVar, fontSize: 12)),
              ],
            ),
          ),
          if (!pending && !rejectedLike) ...[
            const Text('Arena Active',
                style: TextStyle(
                    color: _onSurfaceVar, fontSize: 12, fontWeight: FontWeight.w600)),
            Switch(
              value: arena.isActive,
              activeThumbColor: _greenFixed,
              onChanged: (_) => owner.toggleArenaActive(arena.id),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statsRow(ArenaModel arena) {
    final bookings = OwnerBookingController.to.bookings
        .where((b) => b.arenaId == arena.id)
        .toList();
    final revenue = bookings
        .where((b) =>
            b.status == BookingStatus.confirmed || b.status == BookingStatus.completed)
        .fold(0.0, (acc, b) => acc + b.totalAmount);
    return Row(
      children: [
        Expanded(
            child: _statCard(
                'BOOKINGS', '${bookings.length}', _onSurface, Icons.event_note_outlined)),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard('REVENUE', 'PKR ${_fmtRevenue(revenue)}', _greenFixed,
                Icons.payments_outlined)),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard(
                'COURTS', '${arena.courts.length}', _cyan, Icons.sports_outlined)),
      ],
    );
  }

  Widget _statCard(String label, String value, Color valueColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
          color: _surfaceLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline)),
      child: Column(
        children: [
          Icon(icon, size: 18, color: valueColor),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: valueColor, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: _onSurfaceVar,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4)),
        ],
      ),
    );
  }

  Widget _courtsSection(ArenaModel arena) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Courts (${arena.courts.length})',
                style: const TextStyle(
                    color: _onSurface, fontSize: 17, fontWeight: FontWeight.w800)),
            GestureDetector(
              onTap: () =>
                  Get.toNamed(AppRoutes.editArena, arguments: arena.id),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 16, color: _cyan),
                SizedBox(width: 4),
                Text('Add Court',
                    style: TextStyle(color: _cyan, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (arena.courts.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: _surfaceLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _outline)),
            child: const Text('No courts added yet',
                style: TextStyle(color: _onSurfaceVar)),
          )
        else
          ...arena.courts.map((c) => _courtTile(arena, c)),
      ],
    );
  }

  Widget _courtTile(ArenaModel arena, CourtModel court) {
    final maintenance = !court.isActive;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (maintenance ? _onSurfaceVar : _cyan).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_courtIcon(court.type),
                color: maintenance ? _onSurfaceVar : _cyan),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(court.name,
                    style: TextStyle(
                        color: maintenance ? _onSurfaceVar : _onSurface,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  maintenance
                      ? 'Under Maintenance'
                      : '${court.startTime} – ${court.endTime} · ${court.capacity} cap',
                  style: TextStyle(color: maintenance ? _amber : _onSurfaceVar, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('PKR ${NumberFormat('#,##0').format(court.pricePerHour)}/hr',
                  style: TextStyle(
                      color: maintenance ? _onSurfaceVar : _onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              Switch(
                value: court.isActive,
                activeThumbColor: _greenFixed,
                onChanged: (_) =>
                    OwnerController.to.toggleCourtActive(arena.id, court.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photosSection(BuildContext context, ArenaModel arena) {
    final images = arena.images;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Arena Gallery',
                style: TextStyle(
                    color: _onSurface, fontSize: 17, fontWeight: FontWeight.w800)),
            GestureDetector(
              onTap: () =>
                  Get.toNamed(AppRoutes.editArena, arguments: arena.id),
              child: const Text('Manage Photos',
                  style: TextStyle(color: _cyan, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (images.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: _surfaceLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _outline)),
            child: const Text('No photos yet', style: TextStyle(color: _onSurfaceVar)),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: images.length > 4 ? 4 : images.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.5,
            ),
            itemBuilder: (_, i) {
              final isLastTile = i == 3 && images.length > 4;
              return GestureDetector(
                onTap: () => _showGallery(context, images, i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ArenaImage(path: images[i], borderRadius: BorderRadius.zero),
                      if (isLastTile)
                        Container(
                          color: Colors.black.withValues(alpha: 0.55),
                          alignment: Alignment.center,
                          child: Text('+${images.length - 4} more',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showGallery(BuildContext context, List<String> images, int startIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: startIndex),
              itemCount: images.length,
              itemBuilder: (_, i) =>
                  Center(child: InteractiveViewer(child: Image.network(images[i]))),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Get.back(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationSection(ArenaModel arena) {
    final hasCoords = arena.location.lat != 0 || arena.location.lng != 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Location',
            style: TextStyle(color: _onSurface, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
              color: _surfaceLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _outline)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasCoords)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: SizedBox(
                    height: 140,
                    child: IgnorePointer(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(arena.location.lat, arena.location.lng),
                          zoom: 14,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('arena'),
                            position: LatLng(arena.location.lat, arena.location.lng),
                          ),
                        },
                        zoomControlsEnabled: false,
                        liteModeEnabled: true,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 18, color: _onSurfaceVar),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                arena.location.address.isEmpty
                                    ? 'No address set'
                                    : arena.location.address,
                                style: const TextStyle(color: _onSurfaceVar, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    if (hasCoords) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => MapsLauncher.launchCoordinates(
                            arena.location.lat, arena.location.lng, arena.name),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _onSurface,
                          side: const BorderSide(color: _outline),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: const Size(64, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: const Text('Maps'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _boostBanner(ArenaModel arena) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration:
                BoxDecoration(color: _orange.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: const Icon(Icons.rocket_launch_outlined, color: _orange),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Boost This Arena',
                    style:
                        TextStyle(color: _onSurface, fontSize: 14.5, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Get more visibility and bookings',
                    style: TextStyle(color: _onSurfaceVar, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Get.toNamed(
              AppRoutes.boostRequest,
              arguments: {
                'arenaId': arena.id,
                'arenaName': arena.name,
                'type': BoostType.boost,
              },
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(80, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('BOOST',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }
}
