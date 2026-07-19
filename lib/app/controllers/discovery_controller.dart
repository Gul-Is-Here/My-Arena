import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:maps_launcher/maps_launcher.dart';

import '../data/models/arena_model.dart';
import '../data/models/court_model.dart';
import '../services/arena_service.dart';

enum SortBy { distance, priceLow, priceHigh, rating }

extension SortByX on SortBy {
  String get label {
    switch (this) {
      case SortBy.distance:
        return 'Nearest';
      case SortBy.priceLow:
        return 'Price ↑';
      case SortBy.priceHigh:
        return 'Price ↓';
      case SortBy.rating:
        return 'Top Rated';
    }
  }
}

class DiscoveryController extends GetxController {
  static DiscoveryController get to => Get.find();

  final ArenaService _arenaService = ArenaService();

  final RxBool isMapView = false.obs;
  final Rxn<CourtType> typeFilter = Rxn<CourtType>();
  final RxDouble maxPrice = 5000.0.obs;
  final RxDouble searchRadius = 30.0.obs; // km — 30 default, expandable to 50
  final RxString searchQuery = ''.obs;
  final Rxn<CourtSurface> surfaceFilter = Rxn<CourtSurface>();
  final Rxn<CourtAmenity> amenityFilter = Rxn<CourtAmenity>();
  final RxDouble minRating = 0.0.obs;
  final Rx<SortBy> sortBy = SortBy.distance.obs;
  final RxBool isLoading = true.obs;
  final RxBool noArenasFound = false.obs;
  final RxString cityName = 'Detecting location…'.obs;

  final RxList<ArenaModel> _allArenas = <ArenaModel>[].obs;
  final Rxn<Position> userPosition = Rxn<Position>();

  StreamSubscription? _arenaSub;

  @override
  void onInit() {
    super.onInit();
    ever(typeFilter, (_) => _refreshFiltered());
    ever(surfaceFilter, (_) => _refreshFiltered());
    ever(amenityFilter, (_) => _refreshFiltered());
    ever(maxPrice, (_) => _refreshFiltered());
    ever(minRating, (_) => _refreshFiltered());
    ever(sortBy, (_) => _refreshFiltered());
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

  int get activeFilterCount {
    int n = 0;
    if (typeFilter.value != null) n++;
    if (surfaceFilter.value != null) n++;
    if (amenityFilter.value != null) n++;
    if (minRating.value > 0) n++;
    if (maxPrice.value < 5000) n++;
    if (sortBy.value != SortBy.distance) n++;
    return n;
  }

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
    surfaceFilter.value = null;
    amenityFilter.value = null;
    maxPrice.value = 5000;
    minRating.value = 0;
    searchRadius.value = 30;
    searchQuery.value = '';
    sortBy.value = SortBy.distance;
    _refreshFiltered();
  }

  // ── Computed lists ─────────────────────────────────────────────────────────

  List<ArenaModel> savedArenas(Set<String> ids) =>
      _allArenas.where((a) => ids.contains(a.id)).toList();

  List<ArenaModel> get featured =>
      _allArenas.where((a) => a.isFeatured).toList();

  List<ArenaModel> get nearby {
    final filtered = _allArenas.where((a) {
      if (userPosition.value != null && _distanceTo(a) > searchRadius.value) { return false; }
      if (typeFilter.value != null && !a.courts.any((c) => c.type == typeFilter.value)) { return false; }
      if (surfaceFilter.value != null && !a.courts.any((c) => c.surface == surfaceFilter.value)) { return false; }
      if (amenityFilter.value != null && !a.courts.any((c) => c.amenities.contains(amenityFilter.value))) { return false; }
      if (a.minPrice > maxPrice.value) { return false; }
      if (minRating.value > 0 && a.rating < minRating.value) { return false; }
      if (searchQuery.value.isNotEmpty) {
        final q = searchQuery.value.toLowerCase();
        if (!a.name.toLowerCase().contains(q) &&
            !a.location.address.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (sortBy.value) {
      case SortBy.distance:
        filtered.sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
        break;
      case SortBy.priceLow:
        filtered.sort((a, b) => a.minPrice.compareTo(b.minPrice));
        break;
      case SortBy.priceHigh:
        filtered.sort((a, b) => b.minPrice.compareTo(a.minPrice));
        break;
      case SortBy.rating:
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
    }
    return filtered;
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
