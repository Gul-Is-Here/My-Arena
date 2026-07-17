import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Full-screen map picker — user taps to drop a pin, confirms with bottom sheet.
/// Returns [LocationResult] or null if cancelled.
class LocationPicker extends StatefulWidget {
  final LatLng? initial;
  const LocationPicker({super.key, this.initial});

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  LatLng _picked = const LatLng(31.5204, 74.3587); // default: Lahore

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) _picked = widget.initial!;
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
                style: AppTextStyles.label
                    .copyWith(color: AppColors.primary)),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _picked,
              zoom: 14,
            ),
            onMapCreated: (_) {},
            onTap: (pos) => setState(() => _picked = pos),
            markers: {
              Marker(
                markerId: const MarkerId('picked'),
                position: _picked,
                draggable: true,
                onDragEnd: (pos) => setState(() => _picked = pos),
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          // Bottom confirm card
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Card(
              color: AppColors.darkCard,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_picked.latitude.toStringAsFixed(5)}, '
                      '${_picked.longitude.toStringAsFixed(5)}',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 10),
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

  void _confirm() =>
      Navigator.of(context).pop(LocationResult(latLng: _picked));
}

class LocationResult {
  final LatLng latLng;
  const LocationResult({required this.latLng});
}
