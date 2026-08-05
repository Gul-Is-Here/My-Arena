import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

// Pass key at build time: flutter run --dart-define=MAPS_API_KEY=<key>
const _kMapsKey = String.fromEnvironment(
  'MAPS_API_KEY',
  defaultValue: 'AIzaSyCp0nszGL00-YPtYIR4e-WkNGZ1S0NexEI',
);
const _kDefaultLatLng = LatLng(31.5204, 74.3587);

class LocationPicker extends StatefulWidget {
  final LatLng? initial;
  const LocationPicker({super.key, this.initial});

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _Suggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;
  const _Suggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });
  String get fullLabel =>
      secondaryText.isNotEmpty ? '$mainText, $secondaryText' : mainText;
}

class _LocationPickerState extends State<LocationPicker> {
  LatLng _picked = _kDefaultLatLng;
  String? _address;
  bool _isGeocoding = false;
  int _geocodeSeq = 0;
  final Geocoding _geocoder = Geocoding();

  GoogleMapController? _mapController;
  bool _mapReady = false;

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;
  List<_Suggestion> _suggestions = [];
  bool _searching = false;
  bool _showDropdown = false;
  String _sessionToken = '';

  bool _fetchingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _newSession();
    if (widget.initial != null) {
      _picked = widget.initial!;
      _reverseGeocode(_picked);
    } else {
      _fetchCurrentLocation(animate: false);
    }
  }

  void _newSession() =>
      _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Core: update everything in sync ──────────────────────────────────

  void _moveTo(LatLng pos, {String? address, bool animate = true, double zoom = 15}) {
    setState(() {
      _picked = pos;
      _address = address;
      _locationError = null;
    });
    if (_mapReady && _mapController != null) {
      if (animate) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(pos, zoom));
      } else {
        _mapController!.moveCamera(CameraUpdate.newLatLngZoom(pos, zoom));
      }
    }
    if (address == null) {
      _reverseGeocode(pos);
    }
  }

  // ── Reverse geocoding with sequence guard ────────────────────────────

  Future<void> _reverseGeocode(LatLng pos) async {
    final seq = ++_geocodeSeq;
    setState(() => _isGeocoding = true);
    try {
      final placemarks = await _geocoder.placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted || seq != _geocodeSeq) return;
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          if ((p.name ?? '').isNotEmpty && p.name != p.street) p.name,
          if ((p.subLocality ?? '').isNotEmpty) p.subLocality,
          if ((p.locality ?? '').isNotEmpty) p.locality,
          if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea,
        ].whereType<String>().toSet().toList();
        final resolved = parts.isNotEmpty ? parts.join(', ') : null;
        if (mounted && seq == _geocodeSeq) {
          setState(() {
            _address = resolved;
            _isGeocoding = false;
          });
        }
      } else {
        if (mounted && seq == _geocodeSeq) {
          setState(() => _isGeocoding = false);
        }
      }
    } catch (_) {
      if (mounted && seq == _geocodeSeq) {
        setState(() => _isGeocoding = false);
      }
    }
  }

  // ── Current location ─────────────────────────────────────────────────

  Future<void> _fetchCurrentLocation({bool animate = true}) async {
    setState(() {
      _fetchingLocation = true;
      _locationError = null;
    });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _fetchingLocation = false;
            _locationError = 'Location permission denied. Please enable it in Settings.';
          });
        }
        return;
      }
      if (perm == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _fetchingLocation = false;
            _locationError = 'Location permission required.';
          });
        }
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() {
            _fetchingLocation = false;
            _locationError = 'Location services are disabled.';
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _fetchingLocation = false);
      _moveTo(here, animate: animate);
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetchingLocation = false;
          _locationError = 'Could not get location.';
        });
      }
    }
  }

  // ── Map events ───────────────────────────────────────────────────────

  void _onCameraIdle() {
    // Sync marker to wherever the camera ended up after drag
  }

  void _onMapTap(LatLng pos) {
    _dismissSearch();
    _moveTo(pos);
  }

  void _onMarkerDragEnd(LatLng pos) {
    _dismissSearch();
    _moveTo(pos);
  }

  // ── Search ───────────────────────────────────────────────────────────

  void _dismissSearch() {
    _searchFocus.unfocus();
    setState(() {
      _suggestions = [];
      _showDropdown = false;
    });
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _searching = false;
        _showDropdown = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _autocomplete(query.trim()),
    );
  }

  Future<void> _autocomplete(String query) async {
    if (!mounted) return;

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': query,
          'key': _kMapsKey,
          'sessiontoken': _sessionToken,
          'language': 'en',
          'location': '${_picked.latitude},${_picked.longitude}',
          'radius': '500000',
        },
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (!mounted || _searchCtrl.text.trim() != query) return;

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final predictions = data['predictions'] as List? ?? [];

        if (predictions.isNotEmpty) {
          final results = predictions.map((p) {
            final structured =
                p['structured_formatting'] as Map<String, dynamic>? ?? {};
            return _Suggestion(
              placeId: p['place_id'] as String? ?? '',
              mainText: structured['main_text'] as String? ??
                  p['description'] as String? ??
                  '',
              secondaryText: structured['secondary_text'] as String? ?? '',
            );
          }).where((s) => s.mainText.isNotEmpty).toList();

          if (mounted) {
            setState(() {
              _suggestions = results;
              _searching = false;
              _showDropdown = true;
            });
          }
          return;
        }
      }
    } catch (_) {}

    // Fallback: native geocoder
    await _fallbackSearch(query);
  }

  Future<void> _fallbackSearch(String query) async {
    try {
      final locations = await _geocoder.locationFromAddress(query);
      if (!mounted || _searchCtrl.text.trim() != query) return;
      final results = <_Suggestion>[];
      for (final loc in locations.take(5)) {
        try {
          final placemarks = await _geocoder.placemarkFromCoordinates(
            loc.latitude,
            loc.longitude,
          );
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final main = (p.name?.isNotEmpty == true ? p.name : p.street) ?? query;
            final secondary = [p.subLocality, p.locality]
                .whereType<String>()
                .where((s) => s.isNotEmpty)
                .join(', ');
            results.add(_Suggestion(
              placeId: '${loc.latitude},${loc.longitude}',
              mainText: main,
              secondaryText: secondary,
            ));
          }
        } catch (_) {
          results.add(_Suggestion(
            placeId: '${loc.latitude},${loc.longitude}',
            mainText: query,
            secondaryText:
                '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}',
          ));
        }
      }
      if (mounted) {
        setState(() {
          _suggestions = results;
          _searching = false;
          _showDropdown = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _searching = false;
          _showDropdown = true;
        });
      }
    }
  }

  Future<void> _selectSuggestion(_Suggestion s) async {
    _searchFocus.unfocus();
    final label = s.fullLabel;
    setState(() {
      _searching = true;
      _suggestions = [];
      _showDropdown = false;
      _searchCtrl.text = label;
    });

    // If placeId looks like coordinates (fallback case)
    if (s.placeId.contains(',') && !s.placeId.startsWith('Ch')) {
      final parts = s.placeId.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0]);
        final lng = double.tryParse(parts[1]);
        if (lat != null && lng != null) {
          setState(() => _searching = false);
          _newSession();
          _moveTo(LatLng(lat, lng), address: label);
          return;
        }
      }
    }

    // Real placeId — fetch details from Places API
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': s.placeId,
          'fields': 'geometry',
          'key': _kMapsKey,
          'sessiontoken': _sessionToken,
        },
      );
      _newSession();
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final loc =
            data['result']?['geometry']?['location'] as Map<String, dynamic>?;
        if (loc != null) {
          final latLng = LatLng(
            (loc['lat'] as num).toDouble(),
            (loc['lng'] as num).toDouble(),
          );
          setState(() => _searching = false);
          _moveTo(latLng, address: label);
          return;
        }
      }
    } catch (_) {}

    // Final fallback — geocode the label text
    try {
      final locs = await _geocoder.locationFromAddress(label);
      if (!mounted) return;
      if (locs.isNotEmpty) {
        final latLng = LatLng(locs.first.latitude, locs.first.longitude);
        setState(() => _searching = false);
        _moveTo(latLng, address: label);
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _searching = false);
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _picked, zoom: 14),
            onMapCreated: (ctrl) {
              _mapController = ctrl;
              _mapReady = true;
            },
            onTap: _onMapTap,
            onCameraIdle: _onCameraIdle,
            markers: {
              Marker(
                markerId: const MarkerId('picked'),
                position: _picked,
                draggable: true,
                onDragEnd: _onMarkerDragEnd,
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 80,
              bottom: 180 + bottomInset,
            ),
          ),

          // ── Back button ────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: _circleButton(
              Icons.arrow_back,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),

          // ── Search bar ─────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 60,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 14),
                        child: Icon(Icons.search, size: 20, color: Colors.white38),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          onChanged: _onSearchChanged,
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Search address or area…',
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      if (_searching)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      else if (_searchCtrl.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            _dismissSearch();
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(Icons.close, size: 18, color: Colors.white38),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Suggestions dropdown ─────────────────────────────────
                if (_showDropdown)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 2)),
                      ],
                    ),
                    child: _suggestions.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No results found',
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, color: Colors.white10),
                            itemBuilder: (_, i) {
                              final s = _suggestions[i];
                              return InkWell(
                                onTap: () => _selectSuggestion(s),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_on,
                                          size: 18, color: AppColors.primary),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.mainText,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTextStyles.bodySmall.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (s.secondaryText.isNotEmpty)
                                              Text(
                                                s.secondaryText,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.bodySmall.copyWith(
                                                  color: Colors.white38,
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
              ],
            ),
          ),

          // ── Use Current Location button ────────────────────────────────
          Positioned(
            right: 16,
            bottom: 200 + bottomInset,
            child: Column(
              children: [
                _circleButton(
                  Icons.my_location,
                  onTap: _fetchingLocation ? null : () => _fetchCurrentLocation(),
                  loading: _fetchingLocation,
                ),
              ],
            ),
          ),

          // ── Location error banner ──────────────────────────────────────
          if (_locationError != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 18, color: Colors.black87),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationError!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.black87,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _locationError = null),
                      child: const Icon(Icons.close, size: 16, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom card ────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Address row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.location_on,
                            size: 20, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isGeocoding
                                  ? 'Finding address…'
                                  : (_address ?? 'Tap map to select location'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_picked.latitude.toStringAsFixed(5)}, ${_picked.longitude.toStringAsFixed(5)}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isGeocoding)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.check, size: 20),
                      label: Text(
                        'Confirm Location',
                        style: AppTextStyles.button.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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

  Widget _circleButton(IconData icon, {VoidCallback? onTap, bool loading = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  void _confirm() => Navigator.of(context).pop(
        LocationResult(latLng: _picked, address: _address),
      );
}

class LocationResult {
  final LatLng latLng;
  final String? address;
  const LocationResult({required this.latLng, this.address});
}
