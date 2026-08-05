import 'package:cloud_firestore/cloud_firestore.dart';

import 'court_model.dart';

/// Denormalized summary of an arena's active courts, written by ArenaService
/// after every court add/update/delete so discovery queries never need to
/// fetch the courts subcollection.
class CourtSummary {
  final double minPrice;
  final int courtCount;
  final List<String> sportTypes;
  final List<String> surfaces;
  final List<String> amenities;

  const CourtSummary({
    this.minPrice = 0,
    this.courtCount = 0,
    this.sportTypes = const [],
    this.surfaces = const [],
    this.amenities = const [],
  });

  factory CourtSummary.fromMap(Map<String, dynamic> m) => CourtSummary(
        minPrice: (m['minPrice'] ?? 0).toDouble(),
        courtCount: (m['courtCount'] ?? 0) as int,
        sportTypes: List<String>.from(m['sportTypes'] ?? []),
        surfaces: List<String>.from(m['surfaces'] ?? []),
        amenities: List<String>.from(m['amenities'] ?? []),
      );

  Map<String, dynamic> toMap() => {
        'minPrice': minPrice,
        'courtCount': courtCount,
        'sportTypes': sportTypes,
        'surfaces': surfaces,
        'amenities': amenities,
      };
}

/// Mirrors Firestore arenas/{arenaId} from scope.md.
enum ArenaStatus { pending, approved, rejected, suspended, off, archived }

extension ArenaStatusX on ArenaStatus {
  static ArenaStatus fromString(String? s) => ArenaStatus.values.firstWhere(
        (e) => e.name == s,
        orElse: () => ArenaStatus.pending,
      );
}

class ArenaLocation {
  final String address;
  final double lat;
  final double lng;

  const ArenaLocation({
    required this.address,
    this.lat = 0,
    this.lng = 0,
  });

  /// Returns the address if it's a proper name; otherwise falls back to a
  /// coordinate-derived label so cards never show raw numbers.
  String get displayAddress {
    final a = address.trim();
    if (a.isEmpty) return 'Location pinned';
    // Looks like raw coordinates (e.g. "33.68, 73.04" or "33.6844° N")
    final looksLikeCoords = RegExp(r'^-?\d+\.?\d*[°,\s]').hasMatch(a) &&
        !RegExp(r'[a-zA-Z]{3,}').hasMatch(a);
    if (looksLikeCoords) return 'Location pinned';
    return a;
  }
}

class ArenaModel {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final List<String> images;
  final ArenaLocation location;
  final ArenaStatus status;
  final bool isActive; // Owner ON/OFF
  final bool isFeatured;
  final DateTime? featuredUntil;
  final bool showOnHomeCarousel;
  final int carouselOrder;
  final DateTime? carouselStartDate;
  final DateTime? carouselEndDate;
  final List<CourtModel> courts;
  final double rating;
  final int reviewCount;
  final double distanceKm;
  final CourtSummary? courtSummary;
  final DateTime? nextAvailableSlot;
  final String? rejectionReason;

  const ArenaModel({
    required this.id,
    this.ownerId = '',
    required this.name,
    this.description = '',
    this.images = const [],
    required this.location,
    this.status = ArenaStatus.pending,
    this.isActive = true,
    this.isFeatured = false,
    this.featuredUntil,
    this.showOnHomeCarousel = false,
    this.carouselOrder = 0,
    this.carouselStartDate,
    this.carouselEndDate,
    this.courts = const [],
    this.rating = 0,
    this.reviewCount = 0,
    this.distanceKm = 0,
    this.courtSummary,
    this.nextAvailableSlot,
    this.rejectionReason,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerId': ownerId,
        'name': name,
        'description': description,
        'images': images,
        'location': {
          'address': location.address,
          'lat': location.lat,
          'lng': location.lng,
        },
        'status': status.name,
        'isActive': isActive,
        'isFeatured': isFeatured,
        'showOnHomeCarousel': showOnHomeCarousel,
        'carouselOrder': carouselOrder,
      };

  factory ArenaModel.empty() => ArenaModel(
        id: '',
        ownerId: '',
        name: '',
        description: '',
        images: const [],
        location: const ArenaLocation(address: ''),
      );

  factory ArenaModel.fromMap(Map<String, dynamic> m) {
    final loc = m['location'] as Map<String, dynamic>? ?? {};
    return ArenaModel(
      id: m['id'] ?? '',
      ownerId: m['ownerId'] ?? '',
      name: m['name'] ?? '',
      description: m['description'] ?? '',
      images: List<String>.from(m['images'] ?? []),
      location: ArenaLocation(
        address: loc['address'] ?? '',
        lat: (loc['lat'] ?? 0).toDouble(),
        lng: (loc['lng'] ?? 0).toDouble(),
      ),
      status: ArenaStatusX.fromString(m['status']),
      isActive: (m['isActive'] as bool?) ?? true,
      isFeatured: (m['isFeatured'] as bool?) ?? false,
      showOnHomeCarousel: (m['showOnHomeCarousel'] as bool?) ?? false,
      carouselOrder: (m['carouselOrder'] as int?) ?? 0,
      carouselStartDate: m['carouselStartDate'] != null
          ? (m['carouselStartDate'] as Timestamp).toDate()
          : null,
      carouselEndDate: m['carouselEndDate'] != null
          ? (m['carouselEndDate'] as Timestamp).toDate()
          : null,
      rating: (m['rating'] ?? 0).toDouble(),
      reviewCount: (m['reviewCount'] ?? 0) as int,
      courtSummary: m['courtSummary'] != null
          ? CourtSummary.fromMap(m['courtSummary'] as Map<String, dynamic>)
          : null,
      nextAvailableSlot: m['nextAvailableSlot'] != null
          ? (m['nextAvailableSlot'] as Timestamp).toDate()
          : null,
      rejectionReason: m['rejectionReason'] as String?,
    );
  }

  // Use loaded courts when available (owner/detail screens); fall back to the
  // denormalized summary for discovery listings where courts aren't fetched.
  double get minPrice {
    if (courts.isNotEmpty) {
      return courts.map((c) => c.pricePerHour).reduce((a, b) => a < b ? a : b);
    }
    return courtSummary?.minPrice ?? 0;
  }

  List<String> get summaryTypes =>
      courts.isNotEmpty ? courts.map((c) => c.type.name).toList() : (courtSummary?.sportTypes ?? []);

  List<String> get summarySurfaces =>
      courts.isNotEmpty ? courts.map((c) => c.surface.name).toList() : (courtSummary?.surfaces ?? []);

  List<String> get summaryAmenities =>
      courts.isNotEmpty
          ? courts.expand((c) => c.amenities.map((a) => a.name)).toList()
          : (courtSummary?.amenities ?? []);

  ArenaModel copyWith({
    String? name,
    String? description,
    List<String>? images,
    ArenaLocation? location,
    ArenaStatus? status,
    bool? isActive,
    bool? isFeatured,
    bool? showOnHomeCarousel,
    int? carouselOrder,
    DateTime? carouselStartDate,
    DateTime? carouselEndDate,
    List<CourtModel>? courts,
    CourtSummary? courtSummary,
    DateTime? nextAvailableSlot,
  }) =>
      ArenaModel(
        id: id,
        ownerId: ownerId,
        name: name ?? this.name,
        description: description ?? this.description,
        images: images ?? this.images,
        location: location ?? this.location,
        status: status ?? this.status,
        isActive: isActive ?? this.isActive,
        isFeatured: isFeatured ?? this.isFeatured,
        featuredUntil: featuredUntil,
        showOnHomeCarousel: showOnHomeCarousel ?? this.showOnHomeCarousel,
        carouselOrder: carouselOrder ?? this.carouselOrder,
        carouselStartDate: carouselStartDate ?? this.carouselStartDate,
        carouselEndDate: carouselEndDate ?? this.carouselEndDate,
        courts: courts ?? this.courts,
        rating: rating,
        reviewCount: reviewCount,
        distanceKm: distanceKm,
        courtSummary: courtSummary ?? this.courtSummary,
        nextAvailableSlot: nextAvailableSlot ?? this.nextAvailableSlot,
        rejectionReason: rejectionReason ?? this.rejectionReason,
      );
}
