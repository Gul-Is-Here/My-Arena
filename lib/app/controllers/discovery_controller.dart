import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:maps_launcher/maps_launcher.dart';

import '../data/models/arena_model.dart';
import '../data/models/court_model.dart';
import '../services/arena_service.dart';

class DiscoveryController extends GetxController {
  static DiscoveryController get to => Get.find();

  final ArenaService _arenaService = ArenaService();

  final RxBool isMapView = false.obs;
  final Rxn<CourtType> typeFilter = Rxn<CourtType>();
  final RxDouble maxPrice = 5000.0.obs;
  final RxDouble searchRadius = 30.0.obs; // km — 30 default, expandable to 50
  final RxString searchQuery = ''.obs;
  final RxBool isLoading = true.obs;
  final RxBool noArenasFound = false.obs;
  final RxString cityName = 'Detecting location…'.obs;

  final RxList<ArenaModel> _allArenas = <ArenaModel>[].obs;
  final Rxn<Position> userPosition = Rxn<Position>();

  StreamSubscription? _arenaSub;

  @override
  void onInit() {
    super.onInit();
    _fetchLocation();
    _listenArenas();
  }

  Future<void> _fetchLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        cityName.value = 'Location unavailable';
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low),
      );
      userPosition.value = pos;
      cityName.value = 'Near you';
      _refreshFiltered();
    } catch (_) {
      cityName.value = 'Location unavailable';
    }
  }

  void _listenArenas() {
    _arenaSub = _arenaService.approvedArenas().listen((arenas) {
      _allArenas.assignAll(arenas);
      _refreshFiltered();
      isLoading.value = false;
    }, onError: (_) => isLoading.value = false);
  }

  void _refreshFiltered() {
    noArenasFound.value = nearby.isEmpty;
  }

  // ── Public helpers ─────────────────────────────────────────────────────────

  double distanceOf(ArenaModel arena) => _distanceTo(arena);

  void expandTo50km() {
    searchRadius.value = 50.0;
    _refreshFiltered();
  }

  void resetRadius() {
    searchRadius.value = 30.0;
    _refreshFiltered();
  }

  void toggleMapView() => isMapView.toggle();

  void openInGoogleMaps(ArenaModel arena) {
    MapsLauncher.launchCoordinates(
      arena.location.lat,
      arena.location.lng,
      arena.name,
    );
  }

  void clearFilters() {
    typeFilter.value = null;
    maxPrice.value = 5000;
    searchRadius.value = 30;
    searchQuery.value = '';
    _refreshFiltered();
  }

  // ── Computed lists ─────────────────────────────────────────────────────────

  List<ArenaModel> savedArenas(Set<String> ids) =>
      _allArenas.where((a) => ids.contains(a.id)).toList();

  List<ArenaModel> get featured =>
      _allArenas.where((a) => a.isFeatured).toList();

  List<ArenaModel> get nearby {
    return _allArenas.where((a) {
      final dist = _distanceTo(a);
      if (userPosition.value != null && dist > searchRadius.value) { return false; }
      if (typeFilter.value != null &&
          !a.courts.any((c) => c.type == typeFilter.value)) { return false; }
      if (a.minPrice > maxPrice.value) { return false; }
      if (searchQuery.value.isNotEmpty &&
          !a.name.toLowerCase().contains(searchQuery.value.toLowerCase())) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
  }

  // ── Private ────────────────────────────────────────────────────────────────

  double _distanceTo(ArenaModel arena) {
    final pos = userPosition.value;
    if (pos == null ||
        (arena.location.lat == 0 && arena.location.lng == 0)) {
      return arena.distanceKm;
    }
    return _haversineKm(
      pos.latitude,
      pos.longitude,
      arena.location.lat,
      arena.location.lng,
    );
  }

  double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  void onClose() {
    _arenaSub?.cancel();
    super.onClose();
  }
}
