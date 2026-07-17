import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../controllers/discovery_controller.dart';
import '../../data/models/arena_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/arena_image.dart';
import '../../widgets/glass.dart';

class ArenaMapViewScreen extends StatefulWidget {
  const ArenaMapViewScreen({super.key});

  @override
  State<ArenaMapViewScreen> createState() => _ArenaMapViewScreenState();
}

class _ArenaMapViewScreenState extends State<ArenaMapViewScreen> {
  final _discovery = DiscoveryController.to;
  final Completer<GoogleMapController> _mapCtrl = Completer();

  ArenaModel? _selectedArena;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  // Cache rendered BitmapDescriptors so we don't re-render on every rebuild
  final Map<String, BitmapDescriptor> _iconCache = {};

  static const LatLng _defaultCenter = LatLng(31.5204, 74.3587);

  @override
  void initState() {
    super.initState();
    ever(_discovery.userPosition, (_) => _rebuild());
    ever(_discovery.searchRadius, (_) => _rebuild());
    ever(_discovery.isLoading, (_) {
      if (!_discovery.isLoading.value) _rebuild();
    });
    _rebuild();
  }

  LatLng get _center {
    final pos = _discovery.userPosition.value;
    if (pos == null) return _defaultCenter;
    return LatLng(pos.latitude, pos.longitude);
  }

  Future<void> _rebuild() async {
    if (!mounted) return;
    await _buildMarkersAndCircle();
    _animateCameraToFit();
    if (_discovery.nearby.isEmpty && !_discovery.isLoading.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _show50kmSheet());
    }
  }

  // ── Custom marker rendering ──────────────────────────────────────────────

  Future<BitmapDescriptor> _buildArenaMarkerIcon(ArenaModel arena) async {
    if (_iconCache.containsKey(arena.id)) return _iconCache[arena.id]!;

    const double markerW = 150;
    const double circleR = 44;
    const double circleD = circleR * 2;
    const double labelH = 28;
    const double totalH = circleD + 10 + labelH;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, markerW, totalH),
    );

    // Load image from network
    ui.Image? netImg;
    if (arena.images.isNotEmpty) {
      try {
        final resp =
            await http.get(Uri.parse(arena.images.first)).timeout(
              const Duration(seconds: 5),
            );
        if (resp.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(
            Uint8List.fromList(resp.bodyBytes),
            targetWidth: circleD.toInt(),
            targetHeight: circleD.toInt(),
          );
          final frame = await codec.getNextFrame();
          netImg = frame.image;
        }
      } catch (_) {
        // fall through to placeholder
      }
    }

    final cx = markerW / 2;
    final cy = circleR;

    // Drop shadow
    canvas.drawCircle(
      Offset(cx, cy + 2),
      circleR + 4,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter =
            const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
    );

    // White ring border
    canvas.drawCircle(
      Offset(cx, cy),
      circleR + 3,
      Paint()..color = Colors.white,
    );

    // Primary color ring
    canvas.drawCircle(
      Offset(cx, cy),
      circleR + 1,
      Paint()..color = AppColors.primary,
    );

    // Clip to circle then draw image or placeholder
    canvas.save();
    canvas.clipPath(
      Path()
        ..addOval(
          Rect.fromCircle(center: Offset(cx, cy), radius: circleR),
        ),
    );
    if (netImg != null) {
      canvas.drawImageRect(
        netImg,
        Rect.fromLTWH(
          0,
          0,
          netImg.width.toDouble(),
          netImg.height.toDouble(),
        ),
        Rect.fromCircle(center: Offset(cx, cy), radius: circleR),
        Paint()..filterQuality = FilterQuality.high,
      );
    } else {
      // Placeholder — primary gradient fill + stadium icon
      canvas.drawCircle(
        Offset(cx, cy),
        circleR,
        Paint()..color = AppColors.primary,
      );
      final iconPainter = TextPainter(
        text: const TextSpan(
          text: '🏟️',
          style: TextStyle(fontSize: 32),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(
        canvas,
        Offset(cx - iconPainter.width / 2, cy - iconPainter.height / 2),
      );
    }
    canvas.restore();

    // Name label below the circle
    final name = arena.name.length > 14
        ? '${arena.name.substring(0, 13)}…'
        : arena.name;
    final tp = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: markerW - 8);

    final labelW = (tp.width + 20).clamp(0.0, markerW - 4);
    final labelTop = circleD + 6.0;

    // Label shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, labelTop + labelH / 2 + 1),
          width: labelW,
          height: labelH,
        ),
        const Radius.circular(14),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter =
            const ui.MaskFilter.blur(ui.BlurStyle.normal, 4),
    );

    // Label background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, labelTop + labelH / 2),
          width: labelW,
          height: labelH,
        ),
        const Radius.circular(14),
      ),
      Paint()..color = AppColors.primary,
    );

    // Label text
    tp.paint(
      canvas,
      Offset(
        cx - tp.width / 2,
        labelTop + (labelH - tp.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(markerW.toInt(), totalH.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    final descriptor =
        BitmapDescriptor.bytes(data!.buffer.asUint8List());
    _iconCache[arena.id] = descriptor;
    return descriptor;
  }

  // ── Markers + circle ─────────────────────────────────────────────────────

  Future<void> _buildMarkersAndCircle() async {
    final arenas = _discovery.nearby;
    final radius = _discovery.searchRadius.value * 1000;

    // Build all marker icons in parallel
    final icons = await Future.wait(
      arenas.map((a) => _buildArenaMarkerIcon(a)),
    );

    final newMarkers = <Marker>{};
    for (var i = 0; i < arenas.length; i++) {
      final arena = arenas[i];
      final latLng = LatLng(arena.location.lat, arena.location.lng);
      newMarkers.add(Marker(
        markerId: MarkerId(arena.id),
        position: latLng,
        icon: icons[i],
        onTap: () => setState(() => _selectedArena = arena),
      ));
    }

    final circle = Circle(
      circleId: const CircleId('radius'),
      center: _center,
      radius: radius,
      fillColor: AppColors.primary.withValues(alpha: 0.10),
      strokeColor: AppColors.primary,
      strokeWidth: 2,
    );

    if (!mounted) return;
    setState(() {
      _markers = newMarkers;
      _circles = {circle};
      if (_selectedArena != null &&
          !arenas.any((a) => a.id == _selectedArena!.id)) {
        _selectedArena = null;
      }
    });
  }

  Future<void> _animateCameraToFit() async {
    final ctrl = await _mapCtrl.future;
    final arenas = _discovery.nearby;
    if (arenas.isEmpty) {
      ctrl.animateCamera(
          CameraUpdate.newLatLngZoom(_center, _zoomForRadius()));
      return;
    }

    double minLat = _center.latitude, maxLat = _center.latitude;
    double minLng = _center.longitude, maxLng = _center.longitude;
    for (final a in arenas) {
      if (a.location.lat == 0 && a.location.lng == 0) continue;
      if (a.location.lat < minLat) minLat = a.location.lat;
      if (a.location.lat > maxLat) maxLat = a.location.lat;
      if (a.location.lng < minLng) minLng = a.location.lng;
      if (a.location.lng > maxLng) maxLng = a.location.lng;
    }
    ctrl.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.01, minLng - 0.01),
          northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
        ),
        80,
      ),
    );
  }

  double _zoomForRadius() =>
      _discovery.searchRadius.value <= 30 ? 10.5 : 9.5;

  void _show50kmSheet() {
    if (!mounted) return;
    if (_discovery.searchRadius.value >= 50) {
      Get.snackbar(
        'No arenas found',
        'No arenas found within 50 km either.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.9),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _NoArenasSheet(
        onExpand: () {
          Navigator.pop(context);
          _discovery.expandTo50km();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        actions: [
          Obx(() => Container(
                margin:
                    const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.radio_button_checked,
                        color: AppColors.primary, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${_discovery.searchRadius.value.toStringAsFixed(0)} km',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
      body: Obx(() {
        final pos = _discovery.userPosition.value;
        final center = pos != null
            ? LatLng(pos.latitude, pos.longitude)
            : _defaultCenter;

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: center,
                zoom: _zoomForRadius(),
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              markers: _markers,
              circles: _circles,
              onMapCreated: (ctrl) {
                if (!_mapCtrl.isCompleted) _mapCtrl.complete(ctrl);
                _animateCameraToFit();
              },
              onTap: (_) => setState(() => _selectedArena = null),
            ),

            // Recenter button
            Positioned(
              bottom: _selectedArena != null ? 230 : 40,
              right: 16,
              child: GestureDetector(
                onTap: () async {
                  final ctrl = await _mapCtrl.future;
                  ctrl.animateCamera(
                    CameraUpdate.newLatLngZoom(
                        center, _zoomForRadius()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.my_location,
                      color: AppColors.primary),
                ),
              ),
            ),

            // Arena popup card
            if (_selectedArena != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _ArenaPopupCard(
                  arena: _selectedArena!,
                  distance:
                      _discovery.distanceOf(_selectedArena!),
                  onClose: () =>
                      setState(() => _selectedArena = null),
                ),
              ),

            // Loading overlay
            if (_discovery.isLoading.value)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary),
                ),
              ),
          ],
        );
      }),
    );
  }
}

// ── Arena popup card ──────────────────────────────────────────────────────────

class _ArenaPopupCard extends StatelessWidget {
  final ArenaModel arena;
  final double distance;
  final VoidCallback onClose;
  const _ArenaPopupCard(
      {required this.arena,
      required this.distance,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ArenaImage(
                path:
                    arena.images.isNotEmpty ? arena.images.first : null,
                height: 90,
                width: 90,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    arena.name,
                    style: AppTextStyles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.near_me_outlined,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${distance.toStringAsFixed(1)} km',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textGrey),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.star,
                        size: 13, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      arena.rating.toStringAsFixed(1),
                      style: AppTextStyles.bodySmall,
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    'From PKR ${arena.minPrice.toStringAsFixed(0)}/hr',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Get.toNamed(
                        AppRoutes.arenaDetailCustomer,
                        arguments: arena.id,
                      ),
                      child: const Text('View Details',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close,
                    size: 18, color: AppColors.textGrey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── No Arenas Bottom Sheet ────────────────────────────────────────────────────

class _NoArenasSheet extends StatelessWidget {
  final VoidCallback onExpand;
  const _NoArenasSheet({required this.onExpand});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.location_off_outlined,
              size: 48, color: AppColors.textGrey),
          const SizedBox(height: 12),
          Text('No Arenas Nearby', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          Text(
            "We couldn't find any arenas within 30 km of your location.",
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textGrey),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppColors.textGrey.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.textGrey)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onExpand,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Expand to 50 km'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
