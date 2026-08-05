import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  final RxDouble searchRadius = 30.0.obs;
  final RxString searchQuery = ''.obs;
  final Rxn<CourtSurface> surfaceFilter = Rxn<CourtSurface>();
  final Rxn<CourtAmenity> amenityFilter = Rxn<CourtAmenity>();
  final RxDouble minRating = 0.0.obs;
  final Rx<SortBy> sortBy = SortBy.distance.obs;
  final RxBool isLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxBool noArenasFound = false.obs;
  final RxString cityName = 'Detecting location…'.obs;

  final RxList<ArenaModel> _allArenas = <ArenaModel>[].obs;
  final RxList<ArenaModel> _carouselArenas = <ArenaModel>[].obs;
  final Rxn<Position> userPosition = Rxn<Position>();

  StreamSubscription? _arenaSub;
  StreamSubscription? _carouselSub;
  DocumentSnapshot? _cursor;
  bool _usingGeoStream = false;

  @override
  void onInit() {
    super.onInit();
    ever(typeFilter, (_) => _refreshFiltered());
    ever(surfaceFilter, (_) => _refreshFiltered());
    ever(amenityFilter, (_) => _refreshFiltered());
    ever(maxPrice, (_) => _refreshFiltered());
    ever(minRating, (_) => _refreshFiltered());
    ever(sortBy, (_) => _refreshFiltered());
    ever(searchRadius, (_) => _onRadiusChanged());
    _fetchLocation();
    _listenArenas();
    _listenCarousel();
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
      // Switch from paged fallback to geo stream now that we have location.
      _listenArenas();
    } catch (_) {
      cityName.value = 'Location unavailable';
    }
  }

  void _listenCarousel() {
    _carouselSub?.cancel();
    _carouselSub = _arenaService.carouselArenas().listen(
      (arenas) => _carouselArenas.assignAll(arenas),
      onError: (_) {},
    );
  }

  void _listenArenas() {
    _arenaSub?.cancel();
    _arenaSub = null;
    final pos = userPosition.value;

    if (pos != null) {
      _usingGeoStream = true;
      isLoading.value = true;
      _arenaSub = _arenaService
          .nearbyArenas(pos.latitude, pos.longitude, searchRadius.value)
          .listen(
        (arenas) {
          _allArenas.assignAll(arenas);
          _refreshFiltered();
          isLoading.value = false;
        },
        onError: (_) {
          isLoading.value = false;
          // Geo stream failed (e.g. no position index yet) — fall back to paged.
          _usingGeoStream = false;
          _fetchPagedFallback();
        },
      );
    } else {
      _usingGeoStream = false;
      _fetchPagedFallback();
    }
  }

  void _onRadiusChanged() {
    if (_usingGeoStream) {
      // Re-subscribe with updated radius.
      _listenArenas();
    } else {
      _refreshFiltered();
    }
  }

  Future<void> _fetchPagedFallback({bool reset = true}) async {
    if (reset) {
      _cursor = null;
      hasMore.value = true;
      _allArenas.clear();
      isLoading.value = true;
    }
    try {
      final result =
          await _arenaService.fetchArenaPage(after: _cursor, limit: 20);
      _cursor = result.cursor;
      hasMore.value = result.arenas.length == 20;
      if (reset) {
        _allArenas.assignAll(result.arenas);
      } else {
        _allArenas.addAll(result.arenas);
      }
      _refreshFiltered();
    } catch (_) {
      // silent
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  /// Call from scroll listener to load the next page.
  /// No-op in geo-stream mode (the stream manages its own updates).
  Future<void> loadMore() async {
    if (_usingGeoStream) return;
    if (!hasMore.value || isLoadingMore.value || isLoading.value) return;
    isLoadingMore.value = true;
    await _fetchPagedFallback(reset: false);
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

  void expandTo50km() => searchRadius.value = 50.0;
  void resetRadius() => searchRadius.value = 30.0;
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

  /// Admin-curated arenas for the home carousel (global, not radius-limited).
  List<ArenaModel> get carousel => _carouselArenas.toList();

  /// Featured arenas sorted by distance from the user (nearest first).
  List<ArenaModel> get featured {
    final list = _allArenas.where((a) => a.isFeatured).toList();
    list.sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
    return list;
  }

  List<ArenaModel> get nearby {
    final tf = typeFilter.value;
    final sf = surfaceFilter.value;
    final af = amenityFilter.value;

    final filtered = _allArenas.where((a) {
      if (userPosition.value != null &&
          _distanceTo(a) > searchRadius.value) {
        return false;
      }
      // Use denormalized courtSummary — no courts subcollection fetch needed.
      if (tf != null && !a.summaryTypes.contains(tf.name)) return false;
      if (sf != null && !a.summarySurfaces.contains(sf.name)) return false;
      if (af != null && !a.summaryAmenities.contains(af.name)) return false;
      if (a.minPrice > maxPrice.value) return false;
      if (minRating.value > 0 && a.rating < minRating.value) return false;
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
    _carouselSub?.cancel();
    super.onClose();
  }
}
