import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

const _kMapsKey = 'AIzaSyCp0nszGL00-YPtYIR4e-WkNGZ1S0NexEI';

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
  const _Suggestion(
      {required this.placeId,
      required this.mainText,
      required this.secondaryText});
  String get fullLabel =>
      secondaryText.isNotEmpty ? '$mainText, $secondaryText' : mainText;
}

class _LocationPickerState extends State<LocationPicker> {
  LatLng _picked = const LatLng(31.5204, 74.3587);
  String? _address;
  Timer? _geocodeDebounce;
  final Geocoding _geocoder = Geocoding();
  GoogleMapController? _mapController;

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;
  List<_Suggestion> _suggestions = [];
  bool _searching = false;
  bool _showDropdown = false;
  String _sessionToken = '';

  @override
  void initState() {
    super.initState();
    _newSession();
    if (widget.initial != null) {
      _picked = widget.initial!;
      _resolveAddress();
    } else {
      _useCurrentLocation(animate: false);
    }
  }

  void _newSession() =>
      _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation({bool animate = true}) async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _picked = here;
        _address = null;
      });
      if (animate) {
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(here, 15));
      }
      _resolveAddress();
    } catch (_) {}
  }

  void _onPinMoved(LatLng pos) {
    setState(() {
      _picked = pos;
      _address = null;
      _suggestions = [];
      _showDropdown = false;
    });
    _searchFocus.unfocus();
    _geocodeDebounce?.cancel();
    _geocodeDebounce =
        Timer(const Duration(milliseconds: 400), _resolveAddress);
  }

  Future<void> _resolveAddress() async {
    final target = _picked;
    try {
      final placemarks = await _geocoder.placemarkFromCoordinates(
          target.latitude, target.longitude);
      if (!mounted || target != _picked) return;
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          if ((p.name ?? '').isNotEmpty && p.name != p.street) p.name,
          if ((p.subLocality ?? '').isNotEmpty) p.subLocality,
          if ((p.locality ?? '').isNotEmpty) p.locality,
        ].whereType<String>().toSet().join(', ');
        setState(() => _address = parts.isNotEmpty ? parts : null);
      }
    } catch (_) {}
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
    _searchDebounce = Timer(
        const Duration(milliseconds: 400), () => _autocomplete(query.trim()));
  }

  Future<void> _autocomplete(String query) async {
    if (!mounted) return;
    setState(() {
      _searching = true;
      _showDropdown = false;
    });

    // Try Places Autocomplete first
    try {
      final uri =
          Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
        'input': query,
        'key': _kMapsKey,
        'sessiontoken': _sessionToken,
        'language': 'en',
        'location': '31.5204,74.3587', // bias toward Lahore
        'radius': '500000',
      });
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (!mounted || _searchCtrl.text.trim() != query) return;

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final status = data['status'] as String? ?? '';
        final predictions = data['predictions'] as List? ?? [];

        if ((status == 'OK' || status == 'ZERO_RESULTS') &&
            predictions.isNotEmpty) {
          final results = predictions.map((p) {
            final structured =
                p['structured_formatting'] as Map<String, dynamic>? ?? {};
            return _Suggestion(
              placeId: p['place_id'] as String? ?? '',
              mainText: structured['main_text'] as String? ??
                  p['description'] as String? ??
                  '',
              secondaryText:
                  structured['secondary_text'] as String? ?? '',
            );
          }).where((s) => s.mainText.isNotEmpty).toList();

          setState(() {
            _suggestions = results;
            _searching = false;
            _showDropdown = true;
          });
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
              loc.latitude, loc.longitude);
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
      setState(() {
        _suggestions = results;
        _searching = false;
        _showDropdown = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _searching = false;
          _showDropdown = true; // show empty state
        });
      }
    }
  }

  Future<void> _selectSuggestion(_Suggestion s) async {
    _searchFocus.unfocus();
    setState(() {
      _searching = true;
      _suggestions = [];
      _showDropdown = false;
      _searchCtrl.text = s.fullLabel;
    });

    // If placeId looks like coordinates (fallback case)
    if (s.placeId.contains(',') && !s.placeId.contains(' ')) {
      final parts = s.placeId.split(',');
      try {
        final lat = double.parse(parts[0]);
        final lng = double.parse(parts[1]);
        final latLng = LatLng(lat, lng);
        setState(() {
          _picked = latLng;
          _address = s.fullLabel;
          _searching = false;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
        _newSession();
        return;
      } catch (_) {}
    }

    // Real placeId — fetch details
    try {
      final uri = Uri.https(
          'maps.googleapis.com', '/maps/api/place/details/json', {
        'place_id': s.placeId,
        'fields': 'geometry',
        'key': _kMapsKey,
        'sessiontoken': _sessionToken,
      });
      _newSession();
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final loc =
            data['result']?['geometry']?['location'] as Map<String, dynamic>?;
        if (loc != null) {
          final latLng = LatLng(
              (loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
          setState(() {
            _picked = latLng;
            _address = s.fullLabel;
            _searching = false;
          });
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
          return;
        }
      }
    } catch (_) {}

    // Final fallback — geocode the label
    try {
      final locs = await _geocoder.locationFromAddress(s.fullLabel);
      if (!mounted) return;
      if (locs.isNotEmpty) {
        final latLng = LatLng(locs.first.latitude, locs.first.longitude);
        setState(() {
          _picked = latLng;
          _address = s.fullLabel;
          _searching = false;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: Text('Confirm',
                style: AppTextStyles.label.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _picked, zoom: 14),
            onMapCreated: (ctrl) => _mapController = ctrl,
            onTap: _onPinMoved,
            markers: {
              Marker(
                markerId: const MarkerId('picked'),
                position: _picked,
                draggable: true,
                onDragEnd: _onPinMoved,
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),

          // ── Search overlay ─────────────────────────────────────────────
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search field
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 12),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            focusNode: _searchFocus,
                            onChanged: _onSearchChanged,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Search address or area…',
                              hintStyle: TextStyle(color: Colors.white38),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 15),
                            ),
                          ),
                        ),
                        if (_searching)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary),
                            ),
                          )
                        else if (_searchCtrl.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() {
                                _suggestions = [];
                                _showDropdown = false;
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14),
                              child: Icon(Icons.cancel,
                                  size: 20, color: Colors.white38),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Suggestions dropdown
                  if (_showDropdown)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      constraints: const BoxConstraints(maxHeight: 320),
                      decoration: BoxDecoration(
                        color: AppColors.darkCard,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 12),
                        ],
                      ),
                      child: _suggestions.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No results found',
                                  style: TextStyle(color: Colors.white38)),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              itemCount: _suggestions.length,
                              separatorBuilder: (_, _) => const Divider(
                                  height: 1, color: Colors.white10),
                              itemBuilder: (_, i) {
                                final s = _suggestions[i];
                                return InkWell(
                                  onTap: () => _selectSuggestion(s),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.location_on,
                                            size: 18,
                                            color: AppColors.primary),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                s.mainText,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: AppTextStyles.bodySmall
                                                    .copyWith(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600),
                                              ),
                                              if (s.secondaryText.isNotEmpty)
                                                Text(
                                                  s.secondaryText,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppTextStyles
                                                      .bodySmall
                                                      .copyWith(
                                                          color:
                                                              Colors.white38,
                                                          fontSize: 11),
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
          ),

          // ── Bottom confirm card ────────────────────────────────────────
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Card(
              color: AppColors.darkCard,
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _address ?? 'Finding place name…',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _confirm,
                        child: const Text('Use this location'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirm() => Navigator.of(context)
      .pop(LocationResult(latLng: _picked, address: _address));
}

class LocationResult {
  final LatLng latLng;
  final String? address;
  const LocationResult({required this.latLng, this.address});
}
