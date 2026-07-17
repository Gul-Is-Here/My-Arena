import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../controllers/booking_controller.dart';
import '../../controllers/discovery_controller.dart';
import '../../controllers/favorites_controller.dart';
import '../../data/models/arena_model.dart';
import '../../data/models/court_model.dart';
import '../../data/models/review_model.dart';
import '../../routes/app_routes.dart';
import '../../services/arena_service.dart';
import '../../widgets/arena_image.dart';

class ArenaDetailCustomerScreen extends StatefulWidget {
  const ArenaDetailCustomerScreen({super.key});

  @override
  State<ArenaDetailCustomerScreen> createState() =>
      _ArenaDetailCustomerScreenState();
}

class _ArenaDetailCustomerScreenState extends State<ArenaDetailCustomerScreen> {
  static const _bg = Color(0xFF0B1120);
  static const _surface = Color(0xFF112240);
  static const _surface2 = Color(0xFF0D1B35);
  static const _green = Color(0xFF4ADE80);
  static const _greenCta = Color(0xFF39FF14);
  static const _onBg = Color(0xFFFFFFFF);
  static const _muted = Color(0xFF8899AA);

  int _pageIndex = 0;
  bool _expandDesc = false;
  CourtModel? _selectedCourt;

  final ArenaService _svc = ArenaService();

  @override
  Widget build(BuildContext context) {
    final String arenaId = Get.arguments as String;

    return StreamBuilder<ArenaModel?>(
      stream: _svc.streamArena(arenaId),
      builder: (context, arenaSnap) {
        if (arenaSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: _bg,
            body: Center(child: CircularProgressIndicator(color: _green)),
          );
        }
        final arena = arenaSnap.data;
        if (arena == null) {
          return Scaffold(
            backgroundColor: _bg,
            appBar: AppBar(backgroundColor: _bg, foregroundColor: _onBg),
            body: const Center(
              child: Text('Arena not found', style: TextStyle(color: _onBg)),
            ),
          );
        }

        return StreamBuilder<List<CourtModel>>(
          stream: _svc.courts(arenaId),
          builder: (context, courtsSnap) {
            final courts = courtsSnap.data ?? [];

            // Keep selected court in sync with live data
            if (_selectedCourt != null && courts.isNotEmpty) {
              final idx = courts.indexWhere((c) => c.id == _selectedCourt!.id);
              if (idx == -1) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => setState(() => _selectedCourt = null),
                );
              } else if (courts[idx].pricePerHour !=
                  _selectedCourt!.pricePerHour) {
                final fresh = courts[idx];
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => setState(() => _selectedCourt = fresh),
                );
              }
            }

            return _buildBody(arena, courts);
          },
        );
      },
    );
  }

  Widget _buildBody(ArenaModel arena, List<CourtModel> courts) {
    final arenaId = arena.id;
    final amenities = courts.expand((c) => c.amenities).toSet().toList();
    final sports = courts.map((c) => c.type).toSet().toList();
    final firstCourt = courts.isNotEmpty ? courts.first : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _HeroSection(
                arena: arena,
                arenaId: arenaId,
                pageIndex: _pageIndex,
                onPageChanged: (i) => setState(() => _pageIndex = i),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(arena, courts),
                  _buildLocationHours(arena, firstCourt),
                  if (sports.isNotEmpty) _buildSportChips(sports),
                  if (amenities.isNotEmpty) _buildFacilities(amenities),
                  if (arena.description.isNotEmpty) _buildAbout(arena),
                  _buildCourtSelector(courts),
                  _buildMapSection(arena),
                  _buildReviews(arena, arenaId),
                  const SizedBox(height: 110),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(arena, courts),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────

  Widget _buildHeader(ArenaModel arena, List<CourtModel> courts) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            arena.name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _onBg,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.star, color: _green, size: 18),
              const SizedBox(width: 6),
              Text(
                arena.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _green,
                ),
              ),
              Text(
                ' · ${arena.reviewCount} review${arena.reviewCount == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 14, color: _muted),
              ),
              const Spacer(),
              if (courts.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${courts.length} COURTS',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _green,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (arena.images.length > 1)
                Row(
                  children: List.generate(
                    arena.images.length.clamp(0, 4),
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: i == _pageIndex ? 20 : 6,
                      height: 6,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: i == _pageIndex
                            ? _green
                            : _muted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Location + Hours ──────────────────────────────────────────────

  Widget _buildLocationHours(ArenaModel arena, CourtModel? court) {
    final openHours = court != null
        ? '${_fmtTime(court.startTime)} – ${_fmtTime(court.endTime)}'
        : '8:00 AM – 11:00 PM';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: _green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${arena.location.address} · ${arena.distanceKm.toStringAsFixed(1)} km away',
                  style: const TextStyle(fontSize: 14, color: _onBg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.access_time_outlined, color: _green, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Open Now',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
              Text(
                ' · $openHours',
                style: const TextStyle(fontSize: 14, color: _onBg),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sport chips ───────────────────────────────────────────────────

  Widget _buildSportChips(List<CourtType> sports) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        scrollDirection: Axis.horizontal,
        itemCount: sports.length,
        separatorBuilder: (_, i) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: active ? _green : _muted.withValues(alpha: 0.35),
                width: active ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              sports[i].label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: active ? _green : _onBg,
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Facilities grid ───────────────────────────────────────────────

  Widget _buildFacilities(List<CourtAmenity> amenities) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Facilities & Amenities',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _onBg,
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: amenities.map((a) => _AmenityTile(amenity: a)).toList(),
          ),
        ],
      ),
    );
  }

  // ── About ─────────────────────────────────────────────────────────

  Widget _buildAbout(ArenaModel arena) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About the Arena',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _onBg,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            arena.description,
            maxLines: _expandDesc ? null : 5,
            overflow: _expandDesc
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFFCDD5E0),
              height: 1.65,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _expandDesc = !_expandDesc),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _expandDesc ? 'Show less' : 'Read more',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _green,
                  ),
                ),
                Icon(
                  _expandDesc
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: _green,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Court selector ────────────────────────────────────────────────

  Widget _buildCourtSelector(List<CourtModel> courts) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Select Court',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _onBg,
                ),
              ),
              const Spacer(),
              if (_selectedCourt != null)
                Text(
                  'Tap again to deselect',
                  style: TextStyle(
                    fontSize: 11,
                    color: _muted.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            courts.isEmpty
                ? 'No courts available'
                : 'Choose a court to see pricing',
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
          const SizedBox(height: 14),
          if (courts.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'No active courts at this arena',
                  style: TextStyle(color: _muted, fontSize: 14),
                ),
              ),
            )
          else
            ...courts.map(
              (court) => _CourtCard(
                court: court,
                isSelected: _selectedCourt?.id == court.id,
                onTap: () => setState(() {
                  _selectedCourt = _selectedCourt?.id == court.id
                      ? null
                      : court;
                }),
              ),
            ),
        ],
      ),
    );
  }

  // ── Map ───────────────────────────────────────────────────────────

  Widget _buildMapSection(ArenaModel arena) {
    final hasCoords = arena.location.lat != 0 || arena.location.lng != 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Location',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _onBg,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 200,
              child: Stack(
                children: [
                  if (hasCoords)
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(arena.location.lat, arena.location.lng),
                        zoom: 15,
                      ),
                      liteModeEnabled: true,
                      mapType: MapType.normal,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      markers: {
                        Marker(
                          markerId: const MarkerId('arena'),
                          position: LatLng(
                            arena.location.lat,
                            arena.location.lng,
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen,
                          ),
                        ),
                      },
                    )
                  else
                    Container(
                      color: _surface2,
                      child: const Center(
                        child: Icon(
                          Icons.map_outlined,
                          color: _muted,
                          size: 48,
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () {
                        if (Get.isRegistered<DiscoveryController>()) {
                          DiscoveryController.to.openInGoogleMaps(arena);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.assistant_navigation,
                              color: Color(0xFF002022),
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Get Directions',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF002022),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reviews ───────────────────────────────────────────────────────

  Widget _buildReviews(ArenaModel arena, String arenaId) {
    return StreamBuilder<List<ReviewModel>>(
      stream: _svc.reviewStream(arenaId),
      builder: (context, snap) {
        final reviews = snap.data ?? [];
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Reviews & Ratings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _onBg,
                    ),
                  ),
                  Text(
                    '${reviews.length} review${reviews.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        arena.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          color: _onBg,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (i) {
                          final filled = i < arena.rating.floor();
                          final half = !filled && i < arena.rating;
                          return Icon(
                            half
                                ? Icons.star_half
                                : (filled ? Icons.star : Icons.star_border),
                            color: filled || half
                                ? _green
                                : _muted.withValues(alpha: 0.35),
                            size: 18,
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: List.generate(5, (i) {
                        final star = 5 - i;
                        final pct = _barPctFromReviews(reviews, star);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                            children: [
                              Text(
                                '$star',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _muted,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: _surface,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: pct,
                                      child: Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: _green,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (reviews.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  alignment: Alignment.center,
                  child: const Column(
                    children: [
                      Icon(Icons.rate_review_outlined, color: _muted, size: 36),
                      SizedBox(height: 10),
                      Text(
                        'No reviews yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Be the first to review this arena after your visit',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                )
              else
                ...reviews.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReviewCard(review: r),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────

  Widget _buildBottomBar(ArenaModel arena, List<CourtModel> courts) {
    final court = _selectedCourt;
    final hasSelection = court != null;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 80,
        child: Container(
          color: _bg,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    hasSelection
                        ? RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      'PKR ${court.pricePerHour.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _green,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' / hr',
                                  style: TextStyle(fontSize: 13, color: _muted),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            courts.isEmpty ? 'No courts' : 'Select a court',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _muted,
                            ),
                          ),
                    const SizedBox(height: 4),
                    hasSelection
                        ? Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: _green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                court.name.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _green,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            '${courts.length} courts available',
                            style: const TextStyle(fontSize: 11, color: _muted),
                          ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: hasSelection
                      ? () => _startBooking(arena, court)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: hasSelection ? _greenCta : _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: hasSelection
                          ? null
                          : Border.all(color: _muted.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      hasSelection ? 'Check Availability' : 'Select a Court',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: hasSelection ? const Color(0xFF0A1628) : _muted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  void _startBooking(ArenaModel arena, CourtModel court) {
    if (!Get.isRegistered<BookingController>()) {
      Get.put(BookingController(), permanent: true);
    }
    Get.find<BookingController>().startFlow(arena, court);
    Get.toNamed(AppRoutes.bookingSlot);
  }

  String _fmtTime(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0
        ? 12
        : h > 12
        ? h - 12
        : h;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  double _barPctFromReviews(List<ReviewModel> reviews, int star) {
    if (reviews.isEmpty) return 0;
    final count = reviews.where((r) => r.rating.round() == star).length;
    return (count / reviews.length).clamp(0.0, 1.0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Court selector card
// ─────────────────────────────────────────────────────────────────────────────

class _CourtCard extends StatelessWidget {
  final CourtModel court;
  final bool isSelected;
  final VoidCallback onTap;

  const _CourtCard({
    required this.court,
    required this.isSelected,
    required this.onTap,
  });

  static const _surface = Color(0xFF112240);
  static const _green = Color(0xFF4ADE80);
  static const _muted = Color(0xFF8899AA);
  static const _onBg = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final slots = _parseHour(court.endTime) - _parseHour(court.startTime);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? _green.withValues(alpha: 0.1) : _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _green : Colors.white.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? _green.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.18),
              blurRadius: isSelected ? 20 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _green.withValues(alpha: 0.28),
                          _green.withValues(alpha: 0.1),
                        ],
                      )
                    : null,
                color: isSelected ? null : const Color(0xFF0D1B35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconForType(court.type),
                color: isSelected ? _green : _muted,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    court.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? _green : _onBg,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${court.type.label} · ${court.surface.label} · $slots hrs/day',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'PKR ${court.pricePerHour.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? _green : _onBg,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '/hr',
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
                const SizedBox(height: 6),
                AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: isSelected ? 1 : 0,
                  curve: Curves.easeOutBack,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Color(0xFF0A1628),
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(CourtType t) {
    switch (t) {
      case CourtType.football:
        return Icons.sports_soccer;
      case CourtType.padel:
        return Icons.sports_tennis;
      case CourtType.indoor:
        return Icons.sports_basketball;
      case CourtType.cricket:
        return Icons.sports_cricket;
      case CourtType.other:
        return Icons.stadium_outlined;
    }
  }

  int _parseHour(String hhmm) => int.tryParse(hhmm.split(':').first) ?? 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero section
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final ArenaModel arena;
  final String arenaId;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;

  const _HeroSection({
    required this.arena,
    required this.arenaId,
    required this.pageIndex,
    required this.onPageChanged,
  });

  static const _bg = Color(0xFF0B1120);

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 310,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (arena.images.length > 1)
            PageView.builder(
              itemCount: arena.images.length,
              onPageChanged: onPageChanged,
              itemBuilder: (_, i) => ArenaImage(
                path: arena.images[i],
                height: 310,
                width: double.infinity,
              ),
            )
          else
            ArenaImage(
              path: arena.images.isNotEmpty ? arena.images.first : null,
              height: 310,
              width: double.infinity,
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, _bg.withValues(alpha: 0.9)],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + 10,
            left: 16,
            child: _GlassBtn(icon: Icons.arrow_back, onTap: Get.back),
          ),
          Positioned(
            top: topPad + 10,
            right: 16,
            child: Row(
              children: [
                _GlassBtn(icon: Icons.share_outlined, onTap: () {}),
                const SizedBox(width: 8),
                Obx(() {
                  if (!Get.isRegistered<FavoritesController>()) {
                    return _GlassBtn(icon: Icons.favorite_border, onTap: () {});
                  }
                  final fc = FavoritesController.to;
                  final fav = fc.isFav(arenaId);
                  return _GlassBtn(
                    icon: fav ? Icons.favorite : Icons.favorite_border,
                    iconColor: fav ? const Color(0xFFFF6B6B) : Colors.white,
                    onTap: () => fc.toggle(arenaId),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  const _GlassBtn({required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1A2840).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? Colors.white, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Amenity tile
// ─────────────────────────────────────────────────────────────────────────────

class _AmenityTile extends StatelessWidget {
  final CourtAmenity amenity;
  const _AmenityTile({required this.amenity});

  static const _surface = Color(0xFF112240);
  static const _green = Color(0xFF4ADE80);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_iconFor(amenity), color: _green, size: 26),
          const SizedBox(height: 8),
          Text(
            amenity.label.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.4,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(CourtAmenity a) {
    switch (a) {
      case CourtAmenity.parking:
        return Icons.local_parking;
      case CourtAmenity.changingRooms:
        return Icons.checkroom_outlined;
      case CourtAmenity.floodlights:
        return Icons.wb_sunny_outlined;
      case CourtAmenity.cafeteria:
        return Icons.restaurant_outlined;
      case CourtAmenity.wifi:
        return Icons.wifi;
      case CourtAmenity.showers:
        return Icons.water_drop_outlined;
      case CourtAmenity.firstAid:
        return Icons.medical_services_outlined;
      case CourtAmenity.scoreboard:
        return Icons.scoreboard_outlined;
      case CourtAmenity.referee:
        return Icons.sports_outlined;
      case CourtAmenity.equipment:
        return Icons.sports_handball_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Review card
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  const _ReviewCard({required this.review});

  static const _surface = Color(0xFF112240);
  static const _green = Color(0xFF4ADE80);
  static const _muted = Color(0xFF8899AA);

  String get _initials {
    final parts = review.customerName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].isNotEmpty) return parts[0].substring(0, parts[0].length.clamp(0, 2)).toUpperCase();
    return '??';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()} YR AGO';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()} MO AGO';
    if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()} WK AGO';
    if (diff.inDays >= 1) return '${diff.inDays} DAY${diff.inDays > 1 ? 'S' : ''} AGO';
    if (diff.inHours >= 1) return '${diff.inHours} HR AGO';
    return 'JUST NOW';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3E5A),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _green,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.customerName.isNotEmpty
                          ? review.customerName
                          : 'Anonymous',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeAgo(review.createdAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: _muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) => Icon(
                  i < review.rating.floor()
                      ? Icons.star
                      : (i < review.rating ? Icons.star_half : Icons.star_border),
                  color: i < review.rating ? _green : _muted.withValues(alpha: 0.3),
                  size: 14,
                )),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.comment,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFCDD5E0),
                height: 1.55,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
