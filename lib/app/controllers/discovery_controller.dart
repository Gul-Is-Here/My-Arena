import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:maps_launcher/maps_launcher.dart';

import '../data/models/arena_model.dart';
import '../data/models/court_model.dart';
import '../services/arena_service.dart';

// ── Grouping types ─────────────────────────────────────────────────────────────

/// A city section within a country group.
class ArenaCity {
  final String city;          // display name, e.g. "Lahore"
  final String normalizedCity; // grouping key, e.g. "lahore"
  final List<ArenaModel> arenas; // sorted nearest-first
  final double nearestKm;    // used to sort cities within country

  const ArenaCity({
    required this.city,
    required this.normalizedCity,
    required this.arenas,
    required this.nearestKm,
  });
}

/// A country section containing one or more city groups.
class ArenaCountry {
  final String country;     // display name, e.g. "Pakistan"
  final String countryCode; // ISO 3166-1 alpha-2, e.g. "PK"
  final List<ArenaCity> cities; // sorted nearest-city-first
  final double nearestKm;  // used to sort countries

  const ArenaCountry({
    required this.country,
    required this.countryCode,
    required this.cities,
    required this.nearestKm,
  });
}

// ── Sort preference ─────────────────────────────────────────────────────────────

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

/// Discovery controller — single source of truth for the customer arena list.
///
/// Data model (simple):
///   • [_allArenas] — accumulated pages from Firestore (all approved+active arenas).
///     Every page fetch appends to this list. Never cleared except on full refresh.
///   • Location is fetched once (and on refresh) to compute [_distanceTo].
///
/// Sorting when sortBy == distance (default):
///   • Group A: arenas ≤ 30 km — sorted nearest→farthest
///   • Group B: arenas > 30 km — sorted nearest→farthest
///   • A comes before B in the final list
///   • 30 km is a PRIORITY boundary, never a hard filter — all arenas are always
///     shown regardless of distance.
///
/// When location is unavailable, arenas are sorted by their stored [distanceKm]
/// field (falls back gracefully).
class DiscoveryController extends GetxController {
  static DiscoveryController get to => Get.find();

  final ArenaService _arenaService = ArenaService();

  // ── Filters ────────────────────────────────────────────────────────────────
  final RxBool isMapView = false.obs;
  final Rxn<CourtType> typeFilter = Rxn<CourtType>();
  final RxDouble maxPrice = 5000.0.obs;
  final RxString searchQuery = ''.obs;
  final Rxn<CourtSurface> surfaceFilter = Rxn<CourtSurface>();
  final Rxn<CourtAmenity> amenityFilter = Rxn<CourtAmenity>();
  final RxDouble minRating = 0.0.obs;
  final Rx<SortBy> sortBy = SortBy.distance.obs;

  // ── UI state ───────────────────────────────────────────────────────────────
  final RxBool isLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxBool noArenasFound = false.obs;
  final RxString cityName = 'Detecting location…'.obs;

  // ── Data ───────────────────────────────────────────────────────────────────
  // Single pool — all approved+active arenas loaded via cursor pagination.
  final RxList<ArenaModel> _allArenas = <ArenaModel>[].obs;
  // Featured arenas fetched via their own stream — independent of pagination.
  final RxList<ArenaModel> _featuredArenas = <ArenaModel>[].obs;
  final RxList<ArenaModel> _carouselArenas = <ArenaModel>[].obs;
  final Rxn<Position> userPosition = Rxn<Position>();

  // Pagination state
  DocumentSnapshot? _cursor;
  bool _pageInFlight = false;
  static const int _pageSize = 20;

  // Priority threshold — arenas within this distance appear before those outside.
  static const double _priorityKm = 30.0;

  StreamSubscription? _featuredSub;
  StreamSubscription? _carouselSub;
  StreamSubscription? _authSub;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    ever(typeFilter,    (_) => _refreshFiltered());
    ever(surfaceFilter, (_) => _refreshFiltered());
    ever(amenityFilter, (_) => _refreshFiltered());
    ever(maxPrice,      (_) => _refreshFiltered());
    ever(minRating,     (_) => _refreshFiltered());
    ever(sortBy,        (_) => _refreshFiltered());
    ever(searchQuery,   (_) => _refreshFiltered());
    ever(userPosition,  (_) => _refreshFiltered()); // re-sort when location arrives

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _listenFeatured();
        _listenCarousel();
        _startUp();
      } else {
        _teardown();
      }
    });
  }

  Future<void> _startUp() async {
    isLoading.value = true;
    // Fetch location and first data page in parallel — whichever finishes first
    // will cause the list to render; the other will trigger a re-sort.
    await Future.wait([
      _fetchLocation(),
      _loadNextPage(),
    ]);
  }

  // ── Location ───────────────────────────────────────────────────────────────

  Future<void> _fetchLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        cityName.value = 'Location unavailable';
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low),
      );
      userPosition.value = pos;
      cityName.value = 'Near you';
    } catch (_) {
      cityName.value = 'Location unavailable';
    }
  }

  // ── Pagination ─────────────────────────────────────────────────────────────

  Future<void> _loadNextPage() async {
    if (_pageInFlight || !hasMore.value) return;
    _pageInFlight = true;
    try {
      final result =
          await _arenaService.fetchArenaPage(after: _cursor, limit: _pageSize);
      _cursor = result.cursor;
      hasMore.value = result.arenas.length == _pageSize;

      // Deduplicate — guards against double-call races.
      final seen = _allArenas.map((a) => a.id).toSet();
      final fresh =
          result.arenas.where((a) => !seen.contains(a.id)).toList();
      _allArenas.addAll(fresh);
      _refreshFiltered();
    } catch (e, st) {
      dev.log('DiscoveryController._loadNextPage failed: $e', stackTrace: st);
      // Leave hasMore = true so the user can retry by scrolling.
    } finally {
      _pageInFlight = false;
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  // ── Featured ───────────────────────────────────────────────────────────────

  void _listenFeatured() {
    _featuredSub?.cancel();
    _featuredSub = _arenaService.featuredArenas().listen(
      (arenas) {
        _featuredArenas.assignAll(arenas);
        _refreshFiltered(); // re-sort when featured list changes
      },
      onError: (_) {},
    );
  }

  // ── Carousel ───────────────────────────────────────────────────────────────

  void _listenCarousel() {
    _carouselSub?.cancel();
    _carouselSub = _arenaService.carouselArenas().listen(
      (arenas) => _carouselArenas.assignAll(arenas),
      onError: (_) {},
    );
  }

  // ── Pull-to-refresh ────────────────────────────────────────────────────────

  @override
  Future<void> refresh() async {
    _cursor = null;
    _pageInFlight = false;
    hasMore.value = true;
    _allArenas.clear();
    isLoading.value = true;
    await Future.wait([_fetchLocation(), _loadNextPage()]);
  }

  // ── Teardown ───────────────────────────────────────────────────────────────

  void _teardown() {
    _featuredSub?.cancel();
    _featuredSub = null;
    _carouselSub?.cancel();
    _carouselSub = null;
    _allArenas.clear();
    _featuredArenas.clear();
    _carouselArenas.clear();
    userPosition.value = null;
    _cursor = null;
    _pageInFlight = false;
    hasMore.value = true;
    cityName.value = 'Detecting location…';
    isLoading.value = false;
    isLoadingMore.value = false;
    noArenasFound.value = false;
  }

  void _refreshFiltered() {
    noArenasFound.value = nearby.isEmpty && !isLoading.value;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  double distanceOf(ArenaModel arena) => _distanceTo(arena);

  /// Called by the scroll listener when the user nears the bottom.
  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    await _loadNextPage();
  }

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
    searchQuery.value = '';
    sortBy.value = SortBy.distance;
    _refreshFiltered();
  }

  // ── Computed lists ─────────────────────────────────────────────────────────

  List<ArenaModel> savedArenas(Set<String> ids) =>
      _allArenas.where((a) => ids.contains(a.id)).toList();

  List<ArenaModel> get carousel => _carouselArenas.toList();

  // Hard radius for featured arenas — arenas beyond this are never shown.
  static const double _featuredRadiusKm = 50.0;

  /// Featured arenas within 50 km, sorted nearest-first.
  ///
  /// Uses its own Firestore stream ([_featuredArenas]), completely separate from
  /// the paginated [_allArenas] pool, so no featured arena is ever missed due
  /// to pagination position. When location is unavailable all featured arenas
  /// are returned (no hard filter applies without a reference point).
  List<ArenaModel> get featured {
    final pos = userPosition.value;
    final list = pos == null
        ? _featuredArenas.toList()
        : _featuredArenas
            .where((a) => _distanceTo(a) <= _featuredRadiusKm)
            .toList();
    list.sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
    return list;
  }

  /// The main list consumed by HomeTab and ArenaListScreen.
  ///
  /// All active/approved arenas from [_allArenas] are always shown — the 30 km
  /// value is used only for ordering, never for filtering.
  ///
  /// Default sort (distance):
  ///   • Group A (≤ 30 km) sorted nearest→farthest
  ///   • Group B (> 30 km) sorted nearest→farthest
  ///   • A before B
  ///
  /// Other sort options apply globally without the two-group split.
  List<ArenaModel> get nearby {
    final tf    = typeFilter.value;
    final sf    = surfaceFilter.value;
    final af    = amenityFilter.value;
    final query = searchQuery.value.trim().toLowerCase();
    final bool searching = query.isNotEmpty;

    // Always use the full global pool — no radius filtering.
    final filtered = _allArenas.where((a) {
      if (tf != null && !a.summaryTypes.contains(tf.name)) return false;
      if (sf != null && !a.summarySurfaces.contains(sf.name)) return false;
      if (af != null && !a.summaryAmenities.contains(af.name)) return false;
      if (a.minPrice > maxPrice.value) return false;
      if (minRating.value > 0 && a.rating < minRating.value) return false;
      if (searching) {
        return a.name.toLowerCase().contains(query) ||
            a.location.address.toLowerCase().contains(query);
      }
      return true;
    }).toList();

    switch (sortBy.value) {
      case SortBy.distance:
        // Two-group priority sort:
        //   group A → within _priorityKm, sorted nearest first
        //   group B → beyond _priorityKm, sorted nearest first
        // When searching or when location is unavailable, fall back to a plain
        // distance sort (no two-group split needed).
        if (searching || userPosition.value == null) {
          filtered.sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
        } else {
          final groupA = filtered
              .where((a) => _distanceTo(a) <= _priorityKm)
              .toList()
            ..sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
          final groupB = filtered
              .where((a) => _distanceTo(a) > _priorityKm)
              .toList()
            ..sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
          return [...groupA, ...groupB];
        }
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

  /// Grouped view: Country → City → Arenas, sorted by nearest distance.
  ///
  /// Falls back to the flat [nearby] sort when searching (search uses the flat
  /// grid view, not the grouped view, so this getter is only called when
  /// [searchQuery] is empty).
  List<ArenaCountry> get groupedArenas {
    final arenas = nearby; // already filtered + sorted

    // Group by (countryCode, country) → (normalizedCity, city) → arenas
    final Map<String, Map<String, List<ArenaModel>>> grouped = {};

    for (final a in arenas) {
      final countryKey = a.location.countryCode.isNotEmpty
          ? a.location.countryCode
          : (a.location.country.isNotEmpty ? a.location.country : '__unknown__');
      final cityKey = a.location.normalizedCity.isNotEmpty
          ? a.location.normalizedCity
          : (a.location.city.isNotEmpty ? a.location.city.toLowerCase() : '__unknown__');

      grouped.putIfAbsent(countryKey, () => {});
      grouped[countryKey]!.putIfAbsent(cityKey, () => []);
      grouped[countryKey]![cityKey]!.add(a);
    }

    final result = <ArenaCountry>[];

    for (final countryEntry in grouped.entries) {
      final cities = <ArenaCity>[];

      for (final cityEntry in countryEntry.value.entries) {
        final cityArenas = cityEntry.value; // already sorted by nearby
        final nearestKm = cityArenas.isNotEmpty ? _distanceTo(cityArenas.first) : double.infinity;

        // Resolve display city name — prefer the first arena that has one.
        final displayCity = cityArenas
            .map((a) => a.location.city)
            .firstWhere((c) => c.isNotEmpty, orElse: () => cityEntry.key);

        cities.add(ArenaCity(
          city: displayCity,
          normalizedCity: cityEntry.key,
          arenas: cityArenas,
          nearestKm: nearestKm,
        ));
      }

      // Sort cities within country: nearest-first.
      cities.sort((a, b) => a.nearestKm.compareTo(b.nearestKm));

      final nearestKm = cities.isNotEmpty ? cities.first.nearestKm : double.infinity;

      // Resolve display country name.
      final displayCountry = countryEntry.value.values
          .expand((list) => list)
          .map((a) => a.location.country)
          .firstWhere((c) => c.isNotEmpty, orElse: () => countryEntry.key);

      result.add(ArenaCountry(
        country: displayCountry,
        countryCode: countryEntry.key,
        cities: cities,
        nearestKm: nearestKm,
      ));
    }

    // Sort countries: nearest-first.
    result.sort((a, b) => a.nearestKm.compareTo(b.nearestKm));
    return result;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  double _distanceTo(ArenaModel arena) {
    final pos = userPosition.value;
    if (pos == null ||
        (arena.location.lat == 0 && arena.location.lng == 0)) {
      return arena.distanceKm; // fallback to stored value
    }
    return _haversineKm(
      pos.latitude,
      pos.longitude,
      arena.location.lat,
      arena.location.lng,
    );
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
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
    _featuredSub?.cancel();
    _carouselSub?.cancel();
    _authSub?.cancel();
    super.onClose();
  }
}
